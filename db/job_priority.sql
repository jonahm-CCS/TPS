create or replace function public.tps_command(action text,job_id text default null,employee_id text default null,setting_key text default null,setting_value boolean default null,expected_revision bigint default null) returns jsonb language plpgsql security invoker set search_path='' as $$
declare s public.workspace_settings; o public.operations; e public.employees; message text; q int;
begin
 select * into s from public.workspace_settings where id=true for update;
 if expected_revision is null or expected_revision<>s.revision then raise exception 'The board changed on another station. Refreshed; please try again.' using errcode='40001'; end if;
 if action='priority' then
  if setting_value is null then raise exception 'Priority value is required'; end if;
  update public.jobs set priority=case when setting_value then 'High' else 'Normal' end where id=tps_command.job_id;
  if not found then raise exception 'Job not found'; end if;
  message:='#'||job_id||' priority updated';
 elsif action='setting' then
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
