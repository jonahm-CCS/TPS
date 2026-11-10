-- TPS connected prototype. PostgreSQL tables remain portable for local hosting.
-- Only explicitly approved, verified Supabase Auth users may access this workspace.
create schema if not exists tps_private;
revoke all on schema tps_private from public, anon;
grant usage on schema tps_private to authenticated;
create table tps_private.admin_emails(email text primary key check(email=lower(email)));
alter table tps_private.admin_emails enable row level security;
revoke all on tps_private.admin_emails from public,anon,authenticated;
create function tps_private.is_admin() returns boolean language sql stable security definer
set search_path='' as $$
 select auth.uid() is not null and exists (
 select 1 from auth.users u join tps_private.admin_emails a on a.email=lower(u.email)
 where u.id=auth.uid() and u.email_confirmed_at is not null and not coalesce(u.is_anonymous,false));
$$;
revoke all on function tps_private.is_admin() from public,anon;
grant execute on function tps_private.is_admin() to authenticated;
create table public.production_areas(id text primary key,name text not null,code text unique not null,icon text not null);
create table public.employees(id text primary key,name text not null,area text not null references public.production_areas(id),shift smallint not null check(shift in(1,2)),badge text unique not null,need boolean not null default false);
create index employees_area_idx on public.employees(area);
create table public.jobs(id text primary key,title text not null,part text not null,customer text not null default '',revision text not null,material text not null,qty int not null check(qty>0),priority text not null check(priority in('High','Normal')),due date not null);
create table public.operations(job_id text primary key references public.jobs(id),area text not null references public.production_areas(id),employee text references public.employees(id),status text not null check(status in('Ready','Assigned','In progress','Paused','Blocked','Complete')),done int not null default 0 check(done>=0),operation text not null,notes text not null default '');
create index operations_area_idx on public.operations(area);
create index operations_employee_idx on public.operations(employee);
create unique index one_running_job_per_employee on public.operations(employee) where status='In progress' and employee is not null;
create table public.workspace_settings(id boolean primary key default true check(id),pdf boolean not null default true,notes boolean not null default true,claim boolean not null default true,revision bigint not null default 1);
insert into public.workspace_settings(id) values(true);
create table public.work_events(id uuid primary key default gen_random_uuid(),actor uuid not null,employee text references public.employees(id),job_id text references public.jobs(id),message text not null,created_at timestamptz not null default now());
create index work_events_created_idx on public.work_events(created_at desc);
create index work_events_employee_idx on public.work_events(employee);
create index work_events_job_idx on public.work_events(job_id);
-- All API functions use caller privileges. RLS applies to their queries.
do $$ declare t text; begin
 foreach t in array array['production_areas','employees','jobs','operations','workspace_settings','work_events'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from anon, authenticated',t);
 execute format('grant select,insert,update on public.%I to authenticated',t);
 execute format('create policy admin_read on public.%I for select to authenticated using ((select tps_private.is_admin()))',t);
 execute format('create policy admin_insert on public.%I for insert to authenticated with check ((select tps_private.is_admin()))',t);
 execute format('create policy admin_update on public.%I for update to authenticated using ((select tps_private.is_admin())) with check ((select tps_private.is_admin()))',t);
 end loop;
end $$;
create function public.tps_snapshot() returns jsonb language plpgsql security invoker set search_path='' as $$
declare result jsonb;
begin
 if not tps_private.is_admin() then raise exception 'TPS access has not been granted to this account' using errcode='42501'; end if;
 select jsonb_build_object('version',1,'revision',s.revision,
 'settings',jsonb_build_object('pdf',s.pdf,'notes',s.notes,'claim',s.claim),
 'areas',(select coalesce(jsonb_agg(to_jsonb(a) order by a.id),'[]'::jsonb) from public.production_areas a),
 'employees',(select coalesce(jsonb_agg(to_jsonb(e) order by e.id),'[]'::jsonb) from public.employees e),
 'jobs',(select coalesce(jsonb_agg(to_jsonb(j)-'due'||jsonb_build_object('due',to_char(j.due,'Mon DD'))||to_jsonb(o)-'job_id' order by j.id),'[]'::jsonb) from public.jobs j join public.operations o on o.job_id=j.id),
 'activity',(select coalesce(jsonb_agg(jsonb_build_object('text',v.message,'time',to_char(v.created_at at time zone 'America/New_York','Mon DD HH24:MI')) order by v.created_at desc),'[]'::jsonb) from (select * from public.work_events order by created_at desc limit 15) v)) into result from public.workspace_settings s where id=true;
 return result;
end $$;
create function public.tps_command(action text,job_id text default null,employee_id text default null,setting_key text default null,setting_value boolean default null,expected_revision bigint default null) returns jsonb language plpgsql security invoker set search_path='' as $$
declare s public.workspace_settings; o public.operations; e public.employees; message text; q int;
begin
 if not tps_private.is_admin() then raise exception 'TPS administrator sign-in required' using errcode='42501'; end if;
 select * into s from public.workspace_settings where id=true for update;
 if expected_revision is null or expected_revision<>s.revision then raise exception 'The board changed on another station. Refreshed; please try again.' using errcode='40001'; end if;
 if action='setting' then
  if setting_key not in ('pdf','notes','claim') or setting_value is null then raise exception 'Invalid display setting'; end if;
  update public.workspace_settings set pdf=case when setting_key='pdf' then setting_value else pdf end,notes=case when setting_key='notes' then setting_value else notes end,claim=case when setting_key='claim' then setting_value else claim end where id=true;
  message:='Employee display setting updated: '||setting_key;
 elsif action='need' then
  update public.employees set need=true where id=employee_id returning * into e;
  if not found then raise exception 'Employee not found'; end if;
  message:=e.name||' requested work';
 else
  select * into o from public.operations where operations.job_id=tps_command.job_id for update;
  if not found then raise exception 'Job not found'; end if;
  if employee_id is not null then
   select * into e from public.employees where id=employee_id;
   if not found or e.area<>o.area then raise exception 'Employee must belong to this production area'; end if;
  end if;
  if action='assign' then
   if o.status not in ('Ready','Assigned','Paused') then raise exception 'Job must be paused or ready before reassignment'; end if;
   update public.operations set employee=employee_id,status=case when employee_id is null then 'Ready' else 'Assigned' end where operations.job_id=tps_command.job_id;
  elsif action='claim' then
   if not s.claim or employee_id is null or o.employee is not null or o.status<>'Ready' then raise exception 'Job is no longer available to claim'; end if;
   update public.operations set employee=employee_id,status='Assigned' where operations.job_id=tps_command.job_id;
  else
   if employee_id is null or o.employee is distinct from employee_id then raise exception 'Job is not assigned to this employee'; end if;
   if action='start' then
    if o.status not in ('Assigned','Paused') then raise exception 'Job cannot be started from this status'; end if;
    if exists(select 1 from public.operations where employee=employee_id and status='In progress') then raise exception 'Pause the current job before starting another'; end if;
    update public.operations set status='In progress' where operations.job_id=tps_command.job_id;
   elsif action='pause' then
    if o.status<>'In progress' then raise exception 'Only running work can be paused'; end if;
    update public.operations set status='Paused' where operations.job_id=tps_command.job_id;
   elsif action='complete' then
    if o.status<>'In progress' then raise exception 'Only running work can be completed'; end if;
    select qty into q from public.jobs where id=tps_command.job_id;
    update public.operations set status='Complete',done=q where operations.job_id=tps_command.job_id;
   else raise exception 'Unknown operation'; end if;
  end if;
  if action in ('assign','claim','start') and employee_id is not null then update public.employees set need=false where id=employee_id; end if;
  message:='#'||job_id||' · '||action||coalesce(' · '||e.name,'');
 end if;
 insert into public.work_events(actor,employee,job_id,message) values(auth.uid(),employee_id,job_id,message);
 update public.workspace_settings set revision=revision+1 where id=true;
 return public.tps_snapshot();
end $$;
revoke all on function public.tps_snapshot() from public,anon;
revoke all on function public.tps_command(text,text,text,text,boolean,bigint) from public,anon;
grant execute on function public.tps_snapshot(),public.tps_command(text,text,text,text,boolean,bigint) to authenticated;
