-- Ариадна: ядро тенантности. Владельцы, управление автономией, Telegram-привязки, файлы.
create type sensitivity as enum ('open','private','intimate');

create table owners (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  auth_user_id uuid unique,          -- линк на auth.users, когда владелец заведёт аккаунт
  tz text not null default 'Europe/Moscow',
  created_at timestamptz not null default now()
);

create table governance (
  owner_id uuid primary key references owners(id) on delete cascade,
  autonomy_paused boolean not null default false,
  veto_window_h int not null default 2,
  initiative_budget_day int not null default 3,
  quiet_from smallint,               -- час начала тихих часов (локальное время владельца); null = спросить
  quiet_to smallint,
  updated_at timestamptz not null default now()
);

-- глобальное состояние бота (один бот на всех владельцев)
create table tg_bot (
  id int primary key default 1 check (id = 1),
  enabled boolean not null default true,
  last_update_id bigint not null default 0,
  note text
);
insert into tg_bot (id) values (1);

-- привязка владельца к TG-чату через инвайт-код
create table tg_users (
  owner_id uuid primary key references owners(id) on delete cascade,
  chat_id bigint unique,
  invite_code text unique not null default encode(extensions.gen_random_bytes(6),'hex'),
  bound_at timestamptz,
  enabled boolean not null default true,
  last_alert_at timestamptz not null default now()
);

-- общие файлы (генезис, доки, ремесло — НЕ данные владельцев)
create table files (
  path text primary key,
  kind text not null default 'doc',
  owner text not null default 'ariadna',
  content text not null,
  version int not null default 1,
  updated_at timestamptz not null default now()
);
