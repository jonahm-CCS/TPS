create table public.employee_clock(employee_id text primary key references public.employees(id),clocked_in boolean not null default false,last_in timestamptz,last_out timestamptz);
alter table public.employee_clock enable row level security;
create policy open_clock on public.employee_clock for all to anon,authenticated using(true) with check(true);
grant select,insert,update on public.employee_clock to anon,authenticated;
create function public.tps_clock(employee_key text,clock_in boolean) returns jsonb language plpgsql security invoker set search_path='' as $$
declare c public.employee_clock;
begin
 insert into public.employee_clock(employee_id) values(employee_key) on conflict do nothing;
 select * into c from public.employee_clock where employee_id=employee_key for update;
 if c.clocked_in is distinct from clock_in then
 update public.employee_clock set clocked_in=clock_in,last_in=case when clock_in then now() else last_in end,last_out=case when not clock_in then now() else last_out end where employee_id=employee_key returning * into c;
 insert into public.work_events(actor,employee,message) values(auth.uid(),employee_key,case when clock_in then 'Clocked in' else 'Clocked out' end);
 end if;
 return to_jsonb(c);
end $$;
revoke all on function public.tps_clock(text,boolean) from public;
grant execute on function public.tps_clock(text,boolean) to anon,authenticated;
