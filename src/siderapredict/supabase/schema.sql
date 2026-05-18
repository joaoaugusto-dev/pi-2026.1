create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique check (email <> ''),
  nome text not null default '',
  matricula text not null unique check (matricula <> ''),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.profiles enable row level security;

drop policy if exists "Profiles are readable by owner" on public.profiles;
create policy "Profiles are readable by owner"
on public.profiles
for select
to authenticated
using (auth.uid() = id);

drop policy if exists "Profiles are updatable by owner" on public.profiles;
create policy "Profiles are updatable by owner"
on public.profiles
for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, nome, matricula)
  values (
    new.id,
    lower(coalesce(new.email, '')),
    coalesce(new.raw_user_meta_data ->> 'nome', ''),
    coalesce(new.raw_user_meta_data ->> 'matricula', '')
  )
  on conflict (id) do update
  set
    email = excluded.email,
    nome = excluded.nome,
    matricula = excluded.matricula,
    updated_at = timezone('utc', now());

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.email_for_matricula(matricula_input text)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select p.email
  from public.profiles p
  where p.matricula = trim(matricula_input)
  limit 1;
$$;

create or replace function public.is_matricula_available(
  matricula_input text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not exists (
    select 1
    from public.profiles p
    where p.matricula = trim(matricula_input)
  );
$$;

create or replace function public.is_email_available(email_input text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not exists (
    select 1
    from public.profiles p
    where p.email = lower(trim(email_input))
  );
$$;

grant select, update on public.profiles to authenticated;
grant execute on function public.email_for_matricula(text) to anon, authenticated;
grant execute on function public.is_matricula_available(text) to anon, authenticated;
grant execute on function public.is_email_available(text) to anon, authenticated;

create table if not exists public.measurement_records (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  created_at timestamptz not null,
  payload jsonb not null
);

alter table public.measurement_records drop column if exists inserted_at;
alter table public.measurement_records drop column if exists updated_at;

create index if not exists measurement_records_user_created_idx
on public.measurement_records (user_id, created_at desc);

create index if not exists measurement_records_created_idx
on public.measurement_records (created_at desc);

alter table public.measurement_records enable row level security;

drop policy if exists "Measurement records are readable by owner"
on public.measurement_records;
drop policy if exists "Measurement records are readable by authenticated users"
on public.measurement_records;
create policy "Measurement records are readable by authenticated users"
on public.measurement_records
for select
to authenticated
using (true);

drop policy if exists "Measurement records are insertable by owner"
on public.measurement_records;
create policy "Measurement records are insertable by owner"
on public.measurement_records
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Measurement records are updatable by owner"
on public.measurement_records;
create policy "Measurement records are updatable by owner"
on public.measurement_records
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Measurement records are deletable by owner"
on public.measurement_records;
create policy "Measurement records are deletable by owner"
on public.measurement_records
for delete
to authenticated
using (auth.uid() = user_id);

grant select, insert, update, delete on public.measurement_records
to authenticated;

drop function if exists public.update_measurement_ai(uuid, text, text);

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'measurement-images',
  'measurement-images',
  false,
  20971520,
  array['image/jpeg', 'image/png']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Measurement images are readable by owner"
on storage.objects;
drop policy if exists "Measurement images are readable by authenticated users"
on storage.objects;
create policy "Measurement images are readable by authenticated users"
on storage.objects
for select
to authenticated
using (bucket_id = 'measurement-images');

drop policy if exists "Measurement images are insertable by owner"
on storage.objects;
create policy "Measurement images are insertable by owner"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'measurement-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Measurement images are updatable by owner"
on storage.objects;
create policy "Measurement images are updatable by owner"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'measurement-images'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'measurement-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Measurement images are deletable by owner"
on storage.objects;
create policy "Measurement images are deletable by owner"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'measurement-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

do $$
begin
  alter publication supabase_realtime add table public.measurement_records;
exception
  when duplicate_object then null;
  when undefined_object then null;
end;
$$;
