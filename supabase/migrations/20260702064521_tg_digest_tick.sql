-- Утренний бриф: план дня, ≤3 решения, вопрос про окна. Тихо, если бюджет инициатив/тишина.
create or replace function tg_digest_tick() returns text
language plpgsql security definer set search_path to 'public','pg_temp'
as $fn$
declare o record; v_q int; v_q0 int; v_top text; v_tasks text; v_win text; v_sent int := 0;
begin
  for o in select u.owner_id, ow.name from tg_users u join owners ow on ow.id=u.owner_id
           where u.chat_id is not null and u.enabled
  loop
    if coalesce((select autonomy_paused from governance where owner_id=o.owner_id), false) then continue; end if;

    select count(*), count(*) filter (where priority='P0') into v_q, v_q0
      from bus where owner_id=o.owner_id and dst='owner' and status in ('open','in_progress');
    select string_agg('• ['||coalesce(priority,'—')||'] '||left(subject,80), E'\n' order by
             case coalesce(priority,'') when 'P0' then 0 when 'P1' then 1 else 2 end, created_at)
      into v_top from (select priority, subject, created_at from bus
                       where owner_id=o.owner_id and dst='owner' and status in ('open','in_progress')
                       order by case coalesce(priority,'') when 'P0' then 0 when 'P1' then 1 else 2 end, created_at
                       limit 3) t;
    select string_agg('• '||left(title,80)||coalesce(' (до '||due||')',''), E'\n' order by due nulls last)
      into v_tasks from (select title, due from tasks
                         where owner_id=o.owner_id and status='open'
                         order by due nulls last, created_at limit 5) t;
    select '🏆 '||title into v_win from chronicle
      where owner_id=o.owner_id and at >= current_date - 1 order by created_at desc limit 1;

    perform public.tg_notify(o.owner_id,
      '☀️ <b>Утро.</b>'||E'\n\n'||
      '📥 Решений ждёт: <b>'||coalesce(v_q,0)||'</b> (P0: '||coalesce(v_q0,0)||')'||E'\n'||
      coalesce(v_top,'— пусто —')||E'\n\n'||
      '📝 Задачи дня:'||E'\n'||coalesce(v_tasks,'— пусто —')||
      coalesce(E'\n\n'||v_win,'')||E'\n\n'||
      'Какие окна у тебя сегодня?');
    v_sent := v_sent + 1;
  end loop;
  return 'брифов: '||v_sent;
end $fn$;
revoke execute on function tg_digest_tick() from anon, authenticated;
