-- Апоптоз задач: перенесена ≥4 раз → предложить убить/переродить (с эмпатией, не прокурорски)
create or replace function apoptosis_tick() returns text
language plpgsql security definer set search_path to 'public','pg_temp'
as $fn$
declare r record; v_n int := 0;
begin
  for r in select t.owner_id, count(*) as n,
                  string_agg('• '||left(t.title,70)||' (переносов: '||t.postpone_count||')', E'\n') as items
           from tasks t
           where t.status='open' and t.postpone_count >= 4
             and not exists (select 1 from bus b where b.owner_id=t.owner_id and b.kind='question'
                             and b.subject like 'АПОПТОЗ:%' and b.status in ('open','in_progress')
                             and b.created_at > now() - interval '6 days')
           group by t.owner_id
  loop
    perform public.task_dispatch(r.owner_id, 'ariadna', 'owner',
      'АПОПТОЗ: '||r.n||' задач(и) переносятся снова и снова',
      r.items||E'\n\nДавай честно: убить, переродить или им просто не пришло время? Разрешить НЕ делать — тоже забота.',
      'P2', null, 'question', 'Снять груз вины с бэклога: смерть или перерождение зависших задач.');
    v_n := v_n + 1;
  end loop;
  return 'вопросов: '||v_n;
end $fn$;
revoke execute on function apoptosis_tick() from anon, authenticated;

-- Расписания: входящие TG — каждую минуту (дёшево no-op без токена);
-- эмбеддинги — раз в минуту (rate-limit free-tier: батч 6);
-- утренний бриф 05:00 UTC (08:00 МСК); апоптоз — воскресенье.
select cron.schedule('tg-inbound',  '* * * * *',  $$select public.tg_inbound_tick()$$);
select cron.schedule('mem-embed',   '* * * * *',  $$select public.mem_embed_tick()$$);
select cron.schedule('tg-digest',   '0 5 * * *',  $$select public.tg_digest_tick()$$);
select cron.schedule('apoptosis',   '0 6 * * 0',  $$select public.apoptosis_tick()$$);
