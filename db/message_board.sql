begin;
-- The older integration baseline may not have Command Center roles yet.
create table if not exists tps_private.command_employees (
  employee_number text primary key,
  employee_id text not null references public.employees(id),
  role text not null check(role in ('admin','supervisor')),
  active boolean not null default true
);
alter table tps_private.command_employees enable row level security;
revoke all on tps_private.command_employees from public, anon, authenticated;
create table tps_private.board_identities (
  user_id uuid primary key references auth.users(id) on delete cascade,
  employee_id text not null unique references public.employees(id) on delete cascade
);
create table tps_private.board_conversations (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 1 and 100),
  creator text not null references public.employees(id),
  audience text not null check (audience in ('all','areas','employees')),
  targets text[] not null default '{}',
  archived boolean not null default false,
  updated_at timestamptz not null default now()
);
create table tps_private.board_posts (
  id bigint generated always as identity primary key,
  conversation_id uuid not null references tps_private.board_conversations(id),
  client_key uuid not null,
  sender text not null references public.employees(id),
  body text not null check (char_length(body) <= 4000),
  job_id text references public.jobs(id) on delete set null,
  attachment jsonb,
  sent_at timestamptz not null default now(),
  unique (sender, client_key)
);
create index board_posts_conversation_id on tps_private.board_posts(conversation_id,id);
create table tps_private.board_reads (
  conversation_id uuid not null references tps_private.board_conversations(id),
  employee_id text not null references public.employees(id) on delete cascade,
  last_post bigint not null,
  primary key (conversation_id, employee_id)
);
alter table tps_private.board_identities enable row level security;
alter table tps_private.board_conversations enable row level security;
alter table tps_private.board_posts enable row level security;
alter table tps_private.board_reads enable row level security;
revoke all on tps_private.board_identities, tps_private.board_conversations,
  tps_private.board_posts, tps_private.board_reads from public, anon, authenticated;

create function tps_private.message_board(action text, args jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  actor text;
  actor_area text;
  can_manage boolean;
  chat_id uuid := (args->>'chat')::uuid;
  chat tps_private.board_conversations;
  chat_title text := btrim(args->>'title');
  chat_audience text := args->>'audience';
  chat_targets text[];
  latest bigint;
  post_id bigint;
  post_body text := btrim(coalesce(args->>'body',''));
  job text := nullif(btrim(args->>'job'),'');
  file jsonb := nullif(args->'file','null'::jsonb);
  request_key uuid := (args->>'key')::uuid;
begin
  select i.employee_id,e.area into actor,actor_area
  from tps_private.board_identities i
  join auth.users u on u.id=i.user_id and u.email_confirmed_at is not null and not coalesce(u.is_anonymous,false)
  join public.employees e on e.id=i.employee_id
  where i.user_id=auth.uid();
  if actor is null then
    raise exception 'Your verified account must be linked to a TPS employee by your administrator.' using errcode='42501';
  end if;
  if args->>'employee' is not null and actor <> args->>'employee' then
    raise exception 'This account belongs to a different Employee Station.' using errcode='42501';
  end if;
  can_manage := exists (
    select 1 from tps_private.command_employees c
    where c.employee_number=args->>'number' and c.employee_id=actor and c.active
      and c.role in ('admin','supervisor')
  );

  if action = 'list' then
    return jsonb_build_object('manage',can_manage,'conversations',coalesce((
      select jsonb_agg(to_jsonb(s) order by s.updated_at desc)
      from (
        select c.id,c.title,c.audience,c.targets,c.archived,c.updated_at,c.creator=actor and can_manage as manageable,
          (select count(*) from tps_private.board_posts p
           where p.conversation_id=c.id and p.sender<>actor and p.id>coalesce(r.last_post,0)) as unread
        from tps_private.board_conversations c
        left join tps_private.board_reads r on r.conversation_id=c.id and r.employee_id=actor
        where (not c.archived or (c.creator=actor and can_manage))
          and (c.creator=actor or c.audience='all'
            or (c.audience='areas' and actor_area=any(c.targets))
            or (c.audience='employees' and actor=any(c.targets)))
      ) s
    ),'[]'::jsonb));
  end if;

  if action='create' then
    if not can_manage then raise exception 'Only authorized Command Center users can create chats.' using errcode='42501'; end if;
    if chat_title is null or char_length(chat_title) not between 1 and 100
       or chat_audience is null or chat_audience not in ('all','areas','employees') then
      raise exception 'Enter a chat name and select an audience.';
    end if;
    select coalesce(array_agg(distinct value),'{}') into chat_targets
      from jsonb_array_elements_text(coalesce(args->'targets','[]'::jsonb));
    if chat_audience='all' then chat_targets:='{}'; end if;
    if (chat_audience<>'all' and cardinality(chat_targets)=0) or cardinality(chat_targets)>500
       or (chat_audience='areas' and exists (select 1 from unnest(chat_targets) k where not exists (select 1 from public.production_areas a where a.id=k)))
       or (chat_audience='employees' and exists (select 1 from unnest(chat_targets) k where not exists (select 1 from public.employees e where e.id=k))) then
      raise exception 'Select a valid audience.';
    end if;
    insert into tps_private.board_conversations(title,creator,audience,targets)
      values(chat_title,actor,chat_audience,chat_targets) returning id into chat_id;
    return jsonb_build_object('id',chat_id);
  end if;

  select * into chat from tps_private.board_conversations c where c.id=chat_id for update;
  if not found or not (chat.creator=actor or chat.audience='all'
    or (chat.audience='areas' and actor_area=any(chat.targets))
    or (chat.audience='employees' and actor=any(chat.targets)))
    or (chat.archived and not (chat.creator=actor and can_manage)) then
    raise exception 'This conversation is unavailable.' using errcode='42501';
  end if;

  if action in ('rename','archive','restore') then
    if not can_manage or chat.creator<>actor then
      raise exception 'Only the authorized Command Center creator can manage this chat.' using errcode='42501';
    end if;
    if action='rename' and (chat_title is null or char_length(chat_title) not between 1 and 100) then
      raise exception 'Enter a chat name from 1 to 100 characters.';
    end if;
    update tps_private.board_conversations set title=case when action='rename' then chat_title else title end,
      archived=case when action='archive' then true when action='restore' then false else archived end
      where id=chat_id;
    return '{}'::jsonb;
  elsif action='history' then
    return coalesce((
      select jsonb_agg(to_jsonb(h) order by h.id)
      from (
        select p.id,p.sent_at,p.body,p.job_id,e.name as sender,p.sender=actor as mine,
          p.attachment-'data' as attachment
        from tps_private.board_posts p join public.employees e on e.id=p.sender
        where p.conversation_id=chat_id and (args->>'before' is null or p.id<(args->>'before')::bigint)
        order by p.id desc limit 60
      ) h
    ),'[]'::jsonb);
  elsif action='read' then
    select max(p.id) into latest from tps_private.board_posts p
      where p.conversation_id=chat_id and p.id<=(args->>'through')::bigint;
    if latest is not null then
      insert into tps_private.board_reads as r values(chat_id,actor,latest)
        on conflict (conversation_id,employee_id) do update set last_post=greatest(r.last_post,excluded.last_post);
    end if;
    return '{}'::jsonb;
  elsif action='attachment' then
    return (select attachment from tps_private.board_posts p where p.conversation_id=chat_id and p.id=(args->>'post')::bigint);
  elsif action='send' then
    if chat.archived then raise exception 'This conversation is archived.'; end if;
    if request_key is null or char_length(post_body)>4000 or (post_body='' and job is null and file is null) then
      raise exception 'Enter a message, job reference, or attachment.';
    end if;
    if job is not null and not exists (select 1 from public.jobs j where j.id=job) then
      raise exception 'That job number was not found.';
    end if;
    if file is not null then
      if jsonb_typeof(file) is distinct from 'object'
        or coalesce(char_length(file->>'name'),0) not between 1 and 180
        or coalesce(file->>'type','') not in ('image/jpeg','image/png','image/webp','image/gif','application/pdf')
        or coalesce(char_length(file->>'data'),0) not between 4 and 6990508
        or file->>'data' !~ '^[A-Za-z0-9+/]+={0,2}$'
        or octet_length(decode(file->>'data','base64'))>5242880 then
        raise exception 'Choose a supported image or PDF up to 5 MB.';
      end if;
      file:=jsonb_build_object('name',file->>'name','type',file->>'type','data',file->>'data');
    end if;
    insert into tps_private.board_posts(conversation_id,client_key,sender,body,job_id,attachment)
      values(chat_id,request_key,actor,post_body,job,file)
      on conflict(sender,client_key) do nothing returning id into post_id;
    if post_id is not null then
      update tps_private.board_conversations set updated_at=clock_timestamp() where id=chat_id;
    end if;
    return jsonb_build_object('id',post_id);
  end if;
  raise exception 'Unknown Message Board action.';
end $$;

revoke all on function tps_private.message_board(text,jsonb) from public,anon,authenticated;
grant execute on function tps_private.message_board(text,jsonb) to authenticated;
create function public.tps_message_board(action text,args jsonb)
returns jsonb language sql security invoker set search_path = '' as $$
  select tps_private.message_board(action,args);
$$;
revoke all on function public.tps_message_board(text,jsonb) from public,anon,authenticated;
grant execute on function public.tps_message_board(text,jsonb) to authenticated;
notify pgrst, 'reload schema';
commit;
