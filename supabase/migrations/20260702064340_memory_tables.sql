-- Память Ариадны: симулякр, эпизоды, хроника побед, память отношений, задачи
create table owner_signals (
  id bigint generated always as identity primary key,
  owner_id uuid not null references owners(id) on delete cascade,
  said_at date not null default current_date,
  quote text not null,
  interpretation text not null,
  tags text[] not null default '{}',
  sensitivity sensitivity not null default 'open',
  embedding extensions.vector(1024),
  created_at timestamptz not null default now()
);
create index owner_signals_owner_idx on owner_signals (owner_id, said_at desc);

create table episodes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references owners(id) on delete cascade,
  at timestamptz not null default now(),
  kind text not null default 'event',   -- event|conversation|observation|near_miss
  title text not null,
  body text,
  sensitivity sensitivity not null default 'open',
  embedding extensions.vector(1024),
  embedding_at timestamptz,
  created_at timestamptz not null default now()
);
create index episodes_owner_idx on episodes (owner_id, at desc);

create table chronicle (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references owners(id) on delete cascade,
  at date not null default current_date,
  kind text not null default 'win',     -- win|milestone|anniversary|streak
  title text not null,
  body text,
  created_at timestamptz not null default now()
);

create table relationship_memory (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references owners(id) on delete cascade,
  kind text not null default 'reference', -- joke|reference|word|ritual
  title text not null,
  body text,
  sensitivity sensitivity not null default 'private',
  created_at timestamptz not null default now()
);

-- зеркало задач (до Todoist живёт своё; postpone_count питает апоптоз)
create table tasks (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references owners(id) on delete cascade,
  title text not null,
  notes text,
  status text not null default 'open',  -- open|done|killed|reborn|paused
  priority text,
  due date,
  project text,
  todoist_id text unique,
  postpone_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  done_at timestamptz
);
create index tasks_owner_idx on tasks (owner_id, status);
