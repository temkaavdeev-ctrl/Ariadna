-- RLS с первого байта: владелец видит только своё; anon не видит ничего.
alter table owners enable row level security;
alter table governance enable row level security;
alter table tg_bot enable row level security;
alter table tg_users enable row level security;
alter table files enable row level security;
alter table bus enable row level security;
alter table decisions enable row level security;
alter table lessons enable row level security;
alter table owner_signals enable row level security;
alter table episodes enable row level security;
alter table chronicle enable row level security;
alter table relationship_memory enable row level security;
alter table tasks enable row level security;

-- хелпер: мой owner_id по auth.uid()
create or replace function my_owner_id() returns uuid
language sql stable security definer set search_path to 'public','pg_temp'
as $$ select id from owners where auth_user_id = auth.uid() $$;
revoke execute on function my_owner_id() from anon;

create policy owners_self on owners for select to authenticated using (auth_user_id = auth.uid());
create policy governance_self on governance for all to authenticated using (owner_id = my_owner_id());
create policy tg_users_self on tg_users for select to authenticated using (owner_id = my_owner_id());
create policy bus_self on bus for all to authenticated using (owner_id = my_owner_id());
create policy decisions_self on decisions for all to authenticated using (owner_id = my_owner_id());
create policy owner_signals_self on owner_signals for all to authenticated using (owner_id = my_owner_id());
create policy episodes_self on episodes for all to authenticated using (owner_id = my_owner_id());
create policy chronicle_self on chronicle for all to authenticated using (owner_id = my_owner_id());
create policy relmem_self on relationship_memory for all to authenticated using (owner_id = my_owner_id());
create policy tasks_self on tasks for all to authenticated using (owner_id = my_owner_id());
-- files и lessons: общее ремесло, читаемо аутентифицированным, пишет только сервис
create policy files_read on files for select to authenticated using (true);
create policy lessons_read on lessons for select to authenticated using (true);
-- tg_bot: только сервис (никаких политик)

revoke all on all tables in schema public from anon;
alter default privileges in schema public revoke all on tables from anon;
