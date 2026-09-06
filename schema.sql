create extension if not exists pgcrypto;

create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text,email text,
 role text not null default 'user' check(role in ('user','admin')),
 status text not null default 'pending' check(status in ('pending','approved','rejected','disabled')),
 created_at timestamptz not null default now(),approved_at timestamptz
);
create table if not exists public.access_requests (
 id uuid primary key default gen_random_uuid(),user_id uuid references auth.users(id) on delete cascade,
 full_name text,email text not null,reason text,
 status text not null default 'pending' check(status in ('pending','approved','rejected')),
 created_at timestamptz not null default now(),reviewed_at timestamptz,reviewed_by uuid references auth.users(id)
);
create table if not exists public.agent_details (
 id uuid primary key default gen_random_uuid(),sap_code text,login_id text,agent_id text,email text,
 tl text,am text,bucket text,ojt_nonojt text,shift_status text,sub_process text,
 updated_at timestamptz not null default now(),updated_by uuid references auth.users(id)
);
create unique index if not exists agent_details_email_uq on public.agent_details(lower(email))
 where email is not null and length(trim(email))>0;
create unique index if not exists agent_details_login_uq on public.agent_details(lower(login_id))
 where login_id is not null and length(trim(login_id))>0;

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 insert into public.profiles(id,full_name,email) values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''),new.email)
 on conflict(id) do nothing;
 insert into public.access_requests(user_id,full_name,email,reason)
 values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''),coalesce(new.email,''),coalesce(new.raw_user_meta_data->>'reason','Dashboard access request'));
 return new;
end;$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.profiles where id=auth.uid() and role='admin' and status='approved');$$;
create or replace function public.is_approved_user() returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.profiles where id=auth.uid() and status='approved');$$;

alter table public.profiles enable row level security;
alter table public.access_requests enable row level security;
alter table public.agent_details enable row level security;

drop policy if exists profile_read on public.profiles;
create policy profile_read on public.profiles for select using(id=auth.uid() or public.is_admin());
drop policy if exists profile_admin_update on public.profiles;
create policy profile_admin_update on public.profiles for update using(public.is_admin()) with check(public.is_admin());

drop policy if exists request_read on public.access_requests;
create policy request_read on public.access_requests for select using(user_id=auth.uid() or public.is_admin());
drop policy if exists request_admin_update on public.access_requests;
create policy request_admin_update on public.access_requests for update using(public.is_admin()) with check(public.is_admin());

drop policy if exists agent_read on public.agent_details;
create policy agent_read on public.agent_details for select using(public.is_approved_user());
drop policy if exists agent_admin_insert on public.agent_details;
create policy agent_admin_insert on public.agent_details for insert with check(public.is_admin());
drop policy if exists agent_admin_update on public.agent_details;
create policy agent_admin_update on public.agent_details for update using(public.is_admin()) with check(public.is_admin());
drop policy if exists agent_admin_delete on public.agent_details;
create policy agent_admin_delete on public.agent_details for delete using(public.is_admin());

alter publication supabase_realtime add table public.agent_details;
alter publication supabase_realtime add table public.profiles;
alter publication supabase_realtime add table public.access_requests;

-- After creating your own account, replace the UUID and run:
-- update public.profiles set role='admin',status='approved',approved_at=now()
-- where id='YOUR_AUTH_USER_UUID';