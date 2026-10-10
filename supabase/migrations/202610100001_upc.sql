-- Apply to a fresh Supabase project. Never ship the service-role key in a client.
-- UPC-14 existing Supabase project was migrated safely via staged migrations.
-- Do not reapply this baseline directly to that already initialized project.
create extension if not exists btree_gist with schema extensions;
create extension if not exists pgcrypto with schema extensions;
create table public.accounts (
 id uuid primary key references auth.users(id) on delete cascade,
 role text not null default 'USER' check(role in ('USER','OWNER','ADMIN','SUPPORT','ANALYST')),
 status text not null default 'active' check(status in ('active','suspended','blocked')),
 trial_ends_at timestamptz not null default (now()+interval '7 days'),
 premium_until timestamptz, permanent boolean not null default false,
 created_at timestamptz not null default now()
);
create table public.hotels (
 id uuid primary key, user_id uuid not null references public.accounts(id) on delete cascade,
 name text not null check(length(trim(name)) between 1 and 200),
 city text not null check(city in ('madinah','makkah')), unique(id,user_id)
);
create table public.price_periods (
 id uuid primary key,hotel_id uuid not null,user_id uuid not null,
 from_date date not null,to_date date not null,rates jsonb not null,
 foreign key(hotel_id,user_id) references public.hotels(id,user_id) on delete cascade,
 check(to_date>=from_date),check(jsonb_typeof(rates)='object'),
 exclude using gist(hotel_id with =,daterange(from_date,to_date,'[]') with &&)
);
create table public.drafts (
 user_id uuid primary key references public.accounts(id) on delete cascade,
 body jsonb not null,revision bigint not null default 1,updated_at timestamptz not null default now()
);
create table public.archive (
 id uuid primary key,user_id uuid not null references public.accounts(id) on delete cascade,
 snapshot jsonb not null,saved_at timestamptz not null default now(),unique(id,user_id)
);
create table public.usage_ledger (
 user_id uuid not null references public.accounts(id) on delete cascade,
 calculation_id uuid not null,mode text not null check(mode in ('group','individual')),
 charged_free boolean not null,created_at timestamptz not null default now(),
 primary key(user_id,calculation_id)
);
create table public.preferences(user_id uuid primary key references public.accounts(id) on delete cascade,body jsonb not null default '{}');
create table public.devices(id uuid primary key default gen_random_uuid(),user_id uuid not null references public.accounts(id) on delete cascade,label text,last_seen timestamptz not null default now());
create table public.feedback(id uuid primary key default gen_random_uuid(),user_id uuid not null references public.accounts(id) on delete cascade,kind text not null,body text not null check(length(body) between 1 and 10000),created_at timestamptz not null default now());
create table public.app_settings(id int primary key check(id=1),body jsonb not null default '{}');
insert into public.app_settings(id) values(1);
create table public.audit_log(id bigint generated always as identity primary key,actor_id uuid,subject_id uuid,action text not null,detail jsonb not null default '{}',created_at timestamptz not null default now());
create table public.purchases(id uuid primary key default gen_random_uuid(),user_id uuid not null references public.accounts(id),store text not null,product_id text not null,transaction_id text unique not null,verified_at timestamptz not null,amount_minor bigint,currency text,expires_at timestamptz);
create table public.grants(id uuid primary key default gen_random_uuid(),user_id uuid not null references public.accounts(id) on delete cascade,actor_id uuid not null,plan text not null,created_at timestamptz not null default now());

create function public.new_account() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin insert into public.accounts(id) values(new.id);return new;end; $$;
create trigger upc_new_account after insert on auth.users for each row execute function public.new_account();
-- If deploying after users were created, preserve the original signup trial start.
insert into public.accounts(id,created_at,trial_ends_at)
select id,created_at,created_at+interval '7 days' from auth.users on conflict do nothing;

create function public.active_user() returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.accounts where id=auth.uid() and status='active')
$$;
create function public.is_role(allowed text[]) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.accounts where id=auth.uid() and status='active' and role=any(allowed))
$$;

alter table public.accounts enable row level security;
create policy account_read on public.accounts for select to authenticated using(id=auth.uid());
-- No account insert/update policies: clients cannot change trial, role or premium.
alter table public.hotels enable row level security;
create policy hotels_private on public.hotels for all to authenticated using(user_id=auth.uid() and public.active_user()) with check(user_id=auth.uid() and public.active_user());
alter table public.price_periods enable row level security;
create policy periods_private on public.price_periods for all to authenticated using(user_id=auth.uid() and public.active_user()) with check(user_id=auth.uid() and public.active_user());
alter table public.drafts enable row level security;
create policy drafts_read on public.drafts for select to authenticated using(user_id=auth.uid() and public.active_user());
alter table public.archive enable row level security;
create policy archive_read on public.archive for select to authenticated using(user_id=auth.uid() and public.active_user());
create policy archive_delete on public.archive for delete to authenticated using(user_id=auth.uid() and public.active_user());
alter table public.usage_ledger enable row level security;
create policy usage_read on public.usage_ledger for select to authenticated using(user_id=auth.uid());
alter table public.preferences enable row level security;
create policy preferences_private on public.preferences for all to authenticated using(user_id=auth.uid() and public.active_user()) with check(user_id=auth.uid() and public.active_user());
alter table public.devices enable row level security;
create policy devices_read on public.devices for select to authenticated using(user_id=auth.uid() and public.active_user());
alter table public.feedback enable row level security;
create policy feedback_read on public.feedback for select to authenticated using(user_id=auth.uid() and public.active_user());
create policy feedback_insert on public.feedback for insert to authenticated with check(user_id=auth.uid() and public.active_user());
alter table public.app_settings enable row level security;
create policy settings_read on public.app_settings for select to authenticated using(public.active_user());
alter table public.audit_log enable row level security;
alter table public.purchases enable row level security;
alter table public.grants enable row level security;

create function public.prevent_archive_update() returns trigger language plpgsql set search_path=public,pg_temp as $
begin raise exception 'Archive snapshots are immutable. Use Duplicate.';end; $$;
create trigger immutable_archive before update on public.archive for each row execute function public.prevent_archive_update();
create function public.validate_rates() returns trigger language plpgsql set search_path=public,pg_temp as $
declare k text;v jsonb;
begin
 for k,v in select key,value from jsonb_each(new.rates) loop
  if k !~ '^(GROUP|DBL|TRPL|QUAD)/(roomOnly|bb|hb|fb)$' or jsonb_typeof(v)<>'number' or v::text !~ '^\d+$' or (v::text)::numeric>1000000000000 then raise exception 'Invalid rate key or nonnegative minor-unit amount';end if;
 end loop;
 return new;
end; $$;
create trigger check_period_rates before insert or update on public.price_periods for each row execute function public.validate_rates();

create function public.put_draft(p_body jsonb,p_expected bigint) returns bigint language plpgsql security definer set search_path=public,pg_temp as $$
declare rev bigint;
begin
 if not public.active_user() then raise exception 'ACCOUNT_UNAVAILABLE';end if;
 if pg_column_size(p_body)>2000000 then raise exception 'Draft too large';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,0));
 select revision into rev from public.drafts where user_id=auth.uid() for update;
 if coalesce(rev,0)<>p_expected then raise exception 'DRAFT_CONFLICT';end if;
 insert into public.drafts(user_id,body,revision) values(auth.uid(),p_body,1)
 on conflict(user_id) do update set body=p_body,revision=public.drafts.revision+1,updated_at=now() returning revision into rev;
 return rev;
end; $$;

-- Verify complete per-night math against the supplied frozen inputs. Manual prices
-- are legitimate; server must not recalculate archives against current hotel rates.
create function public.validate_snapshot(p jsonb) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare d jsonb;r jsonb;c jsonb;cr jsonb;l jsonb;n jsonb;s jsonb;city text;mode text;price bigint;q bigint;amt bigint;ct bigint;st bigint:=0;grand bigint:=0;night_count int;expected_rows int;line_count int;plan text;f numeric;in_date date;out_date date;
begin
 if pg_column_size(p)>4000000 or (p->>'schemaVersion')::int<>1 then raise exception 'Invalid snapshot';end if;
 d:=p->'draft';r:=p->'result';mode:=d->>'mode';
 if jsonb_typeof(d)<>'object' or jsonb_typeof(r)<>'object' or jsonb_typeof(d->'services')<>'array' or d->>'id' is null or r->>'total' is null or r->>'services' is null then raise exception 'Incomplete snapshot';end if;
 if mode is null or mode not in ('group','individual') then raise exception 'Invalid mode';end if;
 if length(coalesce(d->>'name',''))>200 then raise exception 'Name too long';end if;
 foreach city in array array['madinah','makkah'] loop
  c:=d->city;cr:=r->city;ct:=0;expected_rows:=0;
  if c->>'enabled' is null or cr->>'total' is null or jsonb_typeof(cr->'nights')<>'array' then raise exception 'Incomplete city';end if;
  if mode='individual' and jsonb_typeof(c->'individual')<>'array' then raise exception 'Invalid room lines';end if;
  if (c->>'enabled')::boolean then
   in_date:=(c->>'checkIn')::date;out_date:=(c->>'checkOut')::date;night_count:=out_date-in_date;
   if night_count<1 or night_count>730 then raise exception 'Invalid stay dates';end if;
   if (c->>'totalPax')::bigint<0 then raise exception 'Invalid guests';end if;
   for l in select value from jsonb_array_elements(case when mode='group' then jsonb_build_array(c->'group') else c->'individual' end) loop
    q:=(l->>'quantity')::bigint;
    if q is null or l->>'id' is null or l->>'plan' is null then raise exception 'Incomplete line';end if;
    if q<0 or q>100000 or (l->>'quantity')!~'^\d+$' then raise exception 'Invalid rooms';end if;
    if mode='individual' and l->>'type' not in ('dbl','trpl','quad') then raise exception 'Invalid room type';end if;
    if q=0 then continue;end if;
    expected_rows:=expected_rows+night_count;line_count:=0;
    for n in select value from jsonb_array_elements(cr->'nights') where value->>'lineId'=l->>'id' loop
     line_count:=line_count+1;price:=(n->>'price')::bigint;plan:=n->>'plan';
     if price is null or plan is null or n->>'date' is null or n->>'type' is null or n->>'quantity' is null or n->>'total' is null then raise exception 'Incomplete nightly row';end if;
     if price<0 or price>1000000000000 or (n->>'price')!~'^\d+$' or plan not in ('roomOnly','bb','hb','fb') or (n->>'quantity')::bigint<>q or (n->>'date')::date<in_date or (n->>'date')::date>=out_date then raise exception 'Invalid nightly price';end if;
     if (n->>'type') <> (case when mode='group' then 'GROUP' else upper(l->>'type') end) then raise exception 'Invalid nightly room type';end if;
     if (select count(*) from jsonb_array_elements(cr->'nights') x where x->>'lineId'=l->>'id' and x->>'date'=n->>'date')<>1 then raise exception 'Duplicate nightly row';end if;
     if l->'overrides' ? (n->>'date') then
      if price<>((l->'overrides'->(n->>'date'))->>'price')::bigint or plan<>((l->'overrides'->(n->>'date'))->>'plan') then raise exception 'Override mismatch';end if;
     else
      if plan<>l->>'plan' then raise exception 'Plan mismatch';end if;
      if l->>'manualPrice' is not null and price<>(l->>'manualPrice')::bigint then raise exception 'Manual rate mismatch';end if;
     end if;
     amt:=price*q;if amt<>(n->>'total')::bigint then raise exception 'Night total mismatch';end if;ct:=ct+amt;
    end loop;
    if line_count<>night_count then raise exception 'Missing nightly prices';end if;
   end loop;
  end if;
  if jsonb_array_length(cr->'nights')<>expected_rows or ct<>(cr->>'total')::bigint then raise exception 'City total mismatch';end if;
  grand:=grand+ct;
 end loop;
 for s in select value from jsonb_array_elements(d->'services') loop
  q:=(s->>'quantity')::bigint;price:=(s->>'unitPrice')::bigint;
  if q is null or price is null or s->>'type' is null or s->>'deduct' is null then raise exception 'Incomplete service';end if;
  if price<0 or q<0 or price>1000000000000 or q>100000 or s->>'type' not in ('fixed','perPerson','quantity') then raise exception 'Invalid service';end if;
  amt:=price*case when s->>'type'='fixed' then 1 else q end*case when (s->>'deduct')::boolean then -1 else 1 end;st:=st+amt;
 end loop;
 if st<>(r->>'services')::bigint or grand+st<>(r->>'total')::bigint then raise exception 'Package total mismatch';end if;
 if d->>'fx' is not null then
  f:=(d->>'fx')::numeric;
  if f<=0 or f>100000 or f::text in ('NaN','Infinity','-Infinity') or f<>(r->>'fx')::numeric or abs(round((grand+st)::numeric/100/f,2)-(r->>'usd')::numeric)>0.01 then raise exception 'Invalid FX conversion';end if;
 elsif r->>'fx' is not null or r->>'usd' is not null then raise exception 'FX unavailable';end if;
end; $$;

create function public.consume_usage(p_id uuid,p_mode text) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare a public.accounts; existing public.usage_ledger;premium boolean;
begin
 select * into a from public.accounts where id=auth.uid() for update;
 if not found or a.status<>'active' then raise exception 'ACCOUNT_UNAVAILABLE';end if;
 select * into existing from public.usage_ledger where user_id=auth.uid() and calculation_id=p_id;
 if found then if existing.mode<>p_mode then raise exception 'Calculation mode changed. Use a new calculation identity.';end if;return;end if;
 premium:=a.permanent or a.premium_until>now() or a.trial_ends_at>now();premium:=coalesce(premium,false);
 if not premium and exists(select 1 from public.usage_ledger where user_id=auth.uid() and mode=p_mode and charged_free) then raise exception 'PREMIUM_REQUIRED';end if;
 insert into public.usage_ledger(user_id,calculation_id,mode,charged_free) values(auth.uid(),p_id,p_mode,not premium);
end; $$;
create function public.submit_calculation(p_snapshot jsonb,p_action text) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare cid uuid; existing public.archive;
begin
 if p_action not in ('save','share') then raise exception 'Invalid action';end if;
 perform public.validate_snapshot(p_snapshot);
 cid:=(p_snapshot->'draft'->>'id')::uuid;
 perform public.consume_usage(cid,p_snapshot->'draft'->>'mode');
 if p_action='save' then
  select * into existing from public.archive where id=cid;
  if found then
   if existing.user_id<>auth.uid() or existing.snapshot<>p_snapshot then raise exception 'Immutable archive collision';end if;
  else insert into public.archive(id,user_id,snapshot) values(cid,auth.uid(),p_snapshot);end if;
 end if;
 return true;
end; $$;
create function public.authorize_share(p_snapshot jsonb,p_text boolean) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if p_text and not public.is_role(array['OWNER']) then raise exception 'OWNER_ONLY';end if;
 perform public.submit_calculation(p_snapshot,'share');return true;
end; $$;

create function public.admin_overview() returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if not public.is_role(array['OWNER','ADMIN','SUPPORT','ANALYST']) then raise exception 'ADMIN_REQUIRED';end if;
 return jsonb_build_object('total_users',(select count(*) from public.accounts),'active_accounts',(select count(*) from public.accounts where status='active'),'trial_users',(select count(*) from public.accounts where trial_ends_at>now()),'premium_users',(select count(*) from public.accounts where permanent or premium_until>now()),'group_usage',(select count(*) from public.usage_ledger where mode='group'),'individual_usage',(select count(*) from public.usage_ledger where mode='individual'),'premium_grants',(select count(*) from public.grants),'blocked_accounts',(select count(*) from public.accounts where status='blocked'));
end; $$;
create function public.admin_users(p_query text default '',p_limit int default 100) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if not public.is_role(array['OWNER','ADMIN','SUPPORT']) then raise exception 'OPERATIONS_REQUIRED';end if;
 return coalesce((select jsonb_agg(row_to_json(t)) from (select a.id,u.email,u.raw_user_meta_data->>'full_name' as full_name,a.role,a.status,a.trial_ends_at,a.premium_until,a.permanent,a.created_at from public.accounts a join auth.users u on u.id=a.id where coalesce(u.email,'') ilike '%'||p_query||'%' or coalesce(u.raw_user_meta_data->>'full_name','') ilike '%'||p_query||'%' order by a.created_at desc limit least(greatest(p_limit,1),100)) t),'[]'::jsonb);
end; $$;
create function public.admin_set_status(p_user uuid,p_status text) returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if not public.is_role(array['OWNER','ADMIN']) then raise exception 'OPERATIONS_REQUIRED';end if;
 if exists(select 1 from public.accounts where id=p_user and role='OWNER') then raise exception 'Cannot suspend owner';end if;
 if p_status not in ('active','suspended','blocked') then raise exception 'Invalid status';end if;
 update public.accounts set status=p_status where id=p_user;
 insert into public.audit_log(actor_id,subject_id,action,detail) values(auth.uid(),p_user,'account_status',jsonb_build_object('status',p_status));
end; $$;
create function public.owner_grant(p_user uuid,p_plan text) returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if not public.is_role(array['OWNER']) then raise exception 'OWNER_ONLY';end if;
 if p_plan not in ('1m','6m','1y','unlimited','remove') then raise exception 'Invalid plan';end if;
 update public.accounts set permanent=(p_plan='unlimited'),premium_until=case p_plan when '1m' then now()+interval '30 days' when '6m' then now()+interval '6 months' when '1y' then now()+interval '1 year' else null end where id=p_user;
 insert into public.grants(user_id,actor_id,plan) values(p_user,auth.uid(),p_plan);
 insert into public.audit_log(actor_id,subject_id,action,detail) values(auth.uid(),p_user,'premium_grant',jsonb_build_object('plan',p_plan));
end; $$;
create function public.owner_configure(p_body jsonb) returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if not public.is_role(array['OWNER']) then raise exception 'OWNER_ONLY';end if;
 update public.app_settings set body=p_body where id=1;
 insert into public.audit_log(actor_id,action,detail) values(auth.uid(),'app_configuration',p_body);
end; $$;
create function public.admin_audit() returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if not public.is_role(array['OWNER','ADMIN','ANALYST']) then raise exception 'ADMIN_REQUIRED';end if;
 return coalesce((select jsonb_agg(row_to_json(t)) from(select * from public.audit_log order by created_at desc limit 200)t),'[]'::jsonb);
end; $$;
create function public.admin_feedback() returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if not public.is_role(array['OWNER','ADMIN','SUPPORT']) then raise exception 'SUPPORT_REQUIRED';end if;
 return coalesce((select jsonb_agg(row_to_json(t)) from(select * from public.feedback order by created_at desc limit 200)t),'[]'::jsonb);
end; $$;
-- Revoke default PUBLIC execution, especially internal privilege functions.
-- Limit revokes to UPC's own functions; never change existing project functions.
revoke all on function public.new_account(),
  public.active_user(),
  public.is_role(text[]),
  public.prevent_archive_update(),
  public.validate_rates(),
  public.put_draft(jsonb,bigint),
  public.validate_snapshot(jsonb),
  public.consume_usage(uuid,text),
  public.submit_calculation(jsonb,text),
  public.authorize_share(jsonb,boolean),
  public.admin_overview(),
  public.admin_users(text,int),
  public.admin_set_status(uuid,text),
  public.owner_grant(uuid,text),
  public.owner_configure(jsonb),
  public.admin_audit(),
  public.admin_feedback() from public,anon,authenticated;
grant execute on function public.active_user(),public.is_role(text[]),public.put_draft(jsonb,bigint),public.submit_calculation(jsonb,text),public.authorize_share(jsonb,boolean),public.admin_overview(),public.admin_users(text,int),public.admin_set_status(uuid,text),public.owner_grant(uuid,text),public.owner_configure(jsonb),public.admin_audit(),public.admin_feedback() to authenticated;
grant usage on schema public to authenticated;
grant select on public.accounts,public.drafts,public.archive,public.usage_ledger,public.devices,public.app_settings to authenticated;
grant select,insert,update,delete on public.hotels,public.price_periods,public.preferences to authenticated;
grant select,insert on public.feedback to authenticated;
grant delete on public.archive to authenticated;
revoke insert,update,delete on public.accounts,public.drafts,public.usage_ledger,public.app_settings,public.devices,public.purchases,public.grants,public.audit_log from authenticated,anon;
revoke insert,update on public.archive from authenticated,anon;
