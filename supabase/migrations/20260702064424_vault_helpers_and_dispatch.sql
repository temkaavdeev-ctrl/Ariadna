-- Секреты только из Vault; координация через task_dispatch/task_close (гены Bookz, тенантные)
create or replace function _secret(p_name text) returns text
language sql stable security definer set search_path to 'vault','pg_temp'
as $$ select decrypted_secret from vault.decrypted_secrets where name = p_name limit 1 $$;
revoke execute on function _secret(text) from anon, authenticated;

create or replace function task_dispatch(
  p_owner_id uuid, p_src text, p_dst text, p_subject text, p_body text,
  p_priority text default null, p_refs text[] default null,
  p_kind text default 'task', p_intent text default null)
returns uuid
language plpgsql security definer set search_path to 'public','pg_temp'
as $fn$
declare v_id uuid;
begin
  insert into bus (owner_id,src,dst,kind,status,subject,body,priority,refs,intent)
  values (p_owner_id,p_src,p_dst,p_kind,'open',p_subject,p_body,p_priority,coalesce(p_refs,'{}'),p_intent)
  returning id into v_id;
  return v_id;
end $fn$;
revoke execute on function task_dispatch(uuid,text,text,text,text,text,text[],text,text) from anon;

create or replace function task_close(
  p_id uuid, p_by text, p_summary text, p_evidence text default null,
  p_notify boolean default true, p_decision_domain text default null, p_affects text[] default null)
returns jsonb
language plpgsql security definer set search_path to 'public','pg_temp'
as $fn$
declare v_task bus%rowtype; v_reply uuid; v_dec uuid;
begin
  select * into v_task from bus where id = p_id for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'задача не найдена'); end if;
  if v_task.status in ('done','closed') then
    return jsonb_build_object('ok', true, 'already_closed', true);
  end if;

  update bus set status='done', claimed_by=p_by, updated_at=now() where id = p_id;

  if p_notify and v_task.src is not null and v_task.src <> v_task.dst then
    insert into bus (owner_id,src,dst,kind,status,subject,body,refs,reply_to)
    values (v_task.owner_id, v_task.dst, v_task.src, 'reply', 'open',
            'ЗАКРЫТО: '||left(v_task.subject,120),
            p_summary || coalesce(E'\nEvidence: '||p_evidence,''),
            array[p_id::text], p_id)
    returning id into v_reply;
  end if;

  if p_decision_domain is not null then
    insert into decisions (owner_id, domain, summary, detail, affects, decided_by)
    values (v_task.owner_id, p_decision_domain, left(p_summary,200),
            p_summary || coalesce(E'\nEvidence: '||p_evidence,'') || E'\nЗадача: '||p_id,
            coalesce(p_affects, array[v_task.dst, v_task.src]), p_by)
    returning id into v_dec;
  end if;

  return jsonb_build_object('ok', true, 'task', p_id, 'reply', v_reply, 'decision', v_dec);
end $fn$;
revoke execute on function task_close(uuid,text,text,text,boolean,text,text[]) from anon;
