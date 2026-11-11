-- Open shared prototype access explicitly requested by the owner.
create or replace function public.tps_snapshot() returns jsonb language plpgsql security invoker set search_path='' as $$
declare result jsonb;
begin
 select jsonb_build_object('version',1,'revision',s.revision,
 'settings',jsonb_build_object('pdf',s.pdf,'notes',s.notes,'claim',s.claim),
 'areas',(select coalesce(jsonb_agg(to_jsonb(a) order by a.id),'[]'::jsonb) from public.production_areas a),
 'employees',(select coalesce(jsonb_agg(to_jsonb(e) order by e.id),'[]'::jsonb) from public.employees e),
 'jobs',(select coalesce(jsonb_agg(to_jsonb(j)-'due'||jsonb_build_object('due',to_char(j.due,'Mon DD'))||to_jsonb(o)-'job_id' order by j.id),'[]'::jsonb) from public.jobs j join public.operations o on o.job_id=j.id),
 'activity',(select coalesce(jsonb_agg(jsonb_build_object('text',v.message,'time',to_char(v.created_at at time zone 'America/New_York','Mon DD HH24:MI')) order by v.created_at desc),'[]'::jsonb) from (select * from public.work_events order by created_at desc limit 15) v)) into result from public.workspace_settings s where id=true;
 return result;
end $$;
create or replace function public.tps_command(action text,job_id text default null,employee_id text default null,setting_key text default null,setting_value boolean default null,expected_revision bigint default null) returns jsonb language plpgsql security invoker set search_path='' as $$
declare s public.workspace_settings; o public.operations; e public.employees; message text; q int;
begin
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

alter table public.work_events alter column actor drop not null;
grant select,insert,update on public.production_areas to anon;
create policy open_workspace on public.production_areas for all to anon using (true) with check (true);
grant select,insert,update on public.employees to anon;
create policy open_workspace on public.employees for all to anon using (true) with check (true);
grant select,insert,update on public.jobs to anon;
create policy open_workspace on public.jobs for all to anon using (true) with check (true);
grant select,insert,update on public.operations to anon;
create policy open_workspace on public.operations for all to anon using (true) with check (true);
grant select,insert,update on public.workspace_settings to anon;
create policy open_workspace on public.workspace_settings for all to anon using (true) with check (true);
grant select,insert,update on public.work_events to anon;
create policy open_workspace on public.work_events for all to anon using (true) with check (true);
grant execute on function public.tps_snapshot(),public.tps_command(text,text,text,text,boolean,bigint) to anon;
