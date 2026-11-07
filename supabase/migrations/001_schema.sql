create type public.app_role as enum('dispatcher', 'master');

create type public.request_status as enum(
  'new',
  'in_progress',
  'rejected',
  'done',
  'closed'
);

create type public.urgency_level as enum('normal', 'urgent');

create table
  public.profiles (
    id uuid primary key references auth.users (id),
    email text not null,
    full_name text default '',
    role public.app_role not null default 'master',
    created_at timestamptz not null default now()
  );

create table
  public.requests (
    id uuid primary key default gen_random_uuid (),
    address text not null,
    description text not null,
    urgency public.urgency_level not null,
    master_id uuid not null references public.profiles (id),
    status public.request_status not null default 'new',
    author_id uuid not null references public.profiles (id),
    created_at timestamptz not null default now()
  );

create table
  public.request_history (
    id bigint generated always as identity primary key,
    request_id uuid not null references public.requests (id) on delete cascade,
    from_status public.request_status,
    to_status public.request_status not null,
    changed_by uuid not null references public.profiles (id),
    comment text,
    created_at timestamptz not null default now()
  );

create function public.handle_new_user () returns trigger language plpgsql security definer
set
  search_path = '' as $$                                    
begin
  insert into public.profiles (id, email, full_name, role)
  values (
    new.id,                                         
    coalesce(new.email, ''),                          
    coalesce(new.raw_user_meta_data ->> 'full_name', ''), 
    case when new.raw_app_meta_data ->> 'role' = 'dispatcher'
         then 'dispatcher'::public.app_role
         else 'master'::public.app_role
    end                                            
  );
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users for each row
execute function public.handle_new_user ();