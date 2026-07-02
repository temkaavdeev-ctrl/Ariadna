-- Эмбеддинги: Voyage API + бэкфилл-тик + semantic recall + сверка с симулякром.
-- Закон: sensitivity='intimate' НЕ эмбеддится никогда.
create or replace function voyage_embed(p_texts text[], p_input_type text default 'document')
returns jsonb
language plpgsql security definer set search_path to 'public','extensions','pg_temp'
as $fn$
declare v_key text; v_status int; v_content text;
begin
  v_key := public._secret('voyage_api_key');
  if v_key is null or array_length(p_texts,1) is null then return null; end if;
  perform extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS','25000');
  select h.status, h.content into v_status, v_content
  from extensions.http((
    'POST', 'https://api.voyageai.com/v1/embeddings',
    ARRAY[extensions.http_header('Authorization','Bearer '||v_key)],
    'application/json',
    jsonb_build_object('input', to_jsonb(p_texts), 'model', 'voyage-3.5', 'input_type', p_input_type)::text
  )::extensions.http_request) h;
  if v_status <> 200 then
    raise notice 'voyage: HTTP % %', v_status, left(v_content, 200);
    return null;
  end if;
  return (v_content::jsonb)->'data';
end $fn$;
revoke execute on function voyage_embed(text[],text) from anon, authenticated;

create or replace function mem_embed_tick() returns text
language plpgsql security definer set search_path to 'public','extensions','pg_temp'
as $fn$
declare v_ids bigint[]; v_uids uuid[]; v_texts text[]; v_data jsonb; i int;
begin
  -- 1) сигналы владельца (симулякр)
  select array_agg(id), array_agg(left(quote||E'\n'||interpretation,1500))
    into v_ids, v_texts
  from (select * from owner_signals where embedding is null and sensitivity <> 'intimate' order by id limit 6) s;
  if v_ids is not null then
    v_data := public.voyage_embed(v_texts,'document');
    if v_data is null then return 'ошибка API (ретрай)'; end if;
    for i in 1..array_length(v_ids,1) loop
      update owner_signals set embedding=((v_data->(i-1))->'embedding')::text::extensions.vector where id=v_ids[i];
    end loop;
    return 'сигналов: '||array_length(v_ids,1);
  end if;
  -- 2) решения
  select array_agg(id), array_agg(left(coalesce(domain,'')||E'\n'||summary||E'\n'||coalesce(detail,''),1500))
    into v_uids, v_texts
  from (select * from decisions where embedding is null order by created_at desc limit 6) d;
  if v_uids is not null then
    v_data := public.voyage_embed(v_texts,'document');
    if v_data is null then return 'ошибка API (ретрай)'; end if;
    for i in 1..array_length(v_uids,1) loop
      update decisions set embedding=((v_data->(i-1))->'embedding')::text::extensions.vector, embedding_at=now() where id=v_uids[i];
    end loop;
    return 'решений: '||array_length(v_uids,1);
  end if;
  -- 3) эпизоды (кроме intimate)
  select array_agg(id), array_agg(left(kind||E'\n'||title||E'\n'||coalesce(body,''),1500))
    into v_uids, v_texts
  from (select * from episodes where embedding is null and sensitivity <> 'intimate' order by at desc limit 6) e;
  if v_uids is not null then
    v_data := public.voyage_embed(v_texts,'document');
    if v_data is null then return 'ошибка API (ретрай)'; end if;
    for i in 1..array_length(v_uids,1) loop
      update episodes set embedding=((v_data->(i-1))->'embedding')::text::extensions.vector, embedding_at=now() where id=v_uids[i];
    end loop;
    return 'эпизодов: '||array_length(v_uids,1);
  end if;
  return 'память эмбеднута полностью';
end $fn$;
revoke execute on function mem_embed_tick() from anon, authenticated;

create or replace function owner_check(p_owner_id uuid, p_text text, p_limit int default 5)
returns table(said_at date, quote text, interpretation text, tags text[], sim real)
language plpgsql stable security definer set search_path to 'public','extensions','pg_temp'
as $fn$
declare v_data jsonb; v_q extensions.vector(1024);
begin
  v_data := public.voyage_embed(array[left(p_text,1000)],'query');
  if v_data is null then return; end if;
  v_q := ((v_data->0)->'embedding')::text::extensions.vector;
  return query
  select s.said_at, s.quote, s.interpretation, s.tags, (1-(s.embedding<=>v_q))::real
  from owner_signals s
  where s.owner_id = p_owner_id and s.embedding is not null
  order by s.embedding<=>v_q limit p_limit;
end $fn$;
revoke execute on function owner_check(uuid,text,int) from anon;

create or replace function mem_recall(p_owner_id uuid, p_text text, p_limit int default 5)
returns table(kind text, ref text, title text, detail text, at_ts timestamptz, sim real)
language plpgsql stable security definer set search_path to 'public','extensions','pg_temp'
as $fn$
declare v_data jsonb; v_q extensions.vector(1024);
begin
  v_data := public.voyage_embed(array[left(p_text,1000)],'query');
  if v_data is null then return; end if;
  v_q := ((v_data->0)->'embedding')::text::extensions.vector;
  return query
  (select 'decision'::text, d.id::text, left(d.summary,160), left(coalesce(d.detail,''),400), d.created_at, (1-(d.embedding<=>v_q))::real
   from decisions d where d.owner_id=p_owner_id and d.embedding is not null
   order by d.embedding<=>v_q limit p_limit)
  union all
  (select 'episode'::text, e.id::text, left(e.title,160), left(coalesce(e.body,''),400), e.at, (1-(e.embedding<=>v_q))::real
   from episodes e where e.owner_id=p_owner_id and e.embedding is not null and e.sensitivity <> 'intimate'
   order by e.embedding<=>v_q limit p_limit)
  order by 6 desc limit p_limit;
end $fn$;
revoke execute on function mem_recall(uuid,text,int) from anon;
