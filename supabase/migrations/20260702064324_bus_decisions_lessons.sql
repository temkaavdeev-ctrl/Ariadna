-- Шина задач (тенантная) + журнал решений + общие уроки ремесла
create table bus (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references owners(id) on delete cascade,
  src text not null,
  dst text not null default 'ariadna',
  kind text not null default 'task',    -- task|flag|fyi|reply|question
  status text not null default 'open',  -- open|in_progress|done|closed|deferred
  priority text,                        -- P0|P1|P2
  subject text not null,
  body text,
  intent text,                          -- намерение: зачем, не только что
  refs text[] not null default '{}',
  reply_to uuid,
  claimed_by text,
  due date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index bus_inbox_idx on bus (owner_id, dst, status);
create index bus_created_idx on bus (created_at);

create table decisions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references owners(id) on delete cascade,
  domain text,
  summary text not null,
  detail text,
  affects text[],
  decided_by text not null,
  embedding extensions.vector(1024),
  embedding_at timestamptz,
  created_at timestamptz not null default now()
);
create index decisions_owner_idx on decisions (owner_id, created_at desc);

-- уроки/антитела: ремесло общее (без owner_id — закон конституции: уроки общие, данные никогда)
create table lessons (
  id uuid primary key default gen_random_uuid(),
  routine text not null default 'ariadna',
  kind text not null default 'pattern', -- pattern|pitfall|calibration|antibody
  lesson text not null,
  ref text,
  created_by text,
  embedding extensions.vector(1024),
  created_at timestamptz not null default now()
);
