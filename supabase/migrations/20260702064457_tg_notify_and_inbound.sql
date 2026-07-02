-- Telegram: уведомление владельцу + двусторонний тик (бинд по инвайт-коду, команды, текст→задача)
create or replace function tg_notify(p_owner_id uuid, p_text text) returns bigint
language plpgsql security definer set search_path to 'public','net','pg_temp'
as $fn$
declare v_chat bigint; v_tok text; v_req bigint;
begin
  select chat_id into v_chat from tg_users where owner_id = p_owner_id and enabled and chat_id is not null;
  v_tok := public._secret('tg_bot_token');
  if v_chat is null or v_tok is null then return null; end if;
  select net.http_post(
    url := 'https://api.telegram.org/bot'||v_tok||'/sendMessage',
    body := jsonb_build_object('chat_id', v_chat, 'text', left(p_text, 4000),
                               'parse_mode', 'HTML', 'disable_web_page_preview', true)
  ) into v_req;
  return v_req;
end $fn$;
revoke execute on function tg_notify(uuid,text) from anon, authenticated;

create or replace function tg_inbound_tick() returns text
language plpgsql security definer set search_path to 'public','extensions','pg_temp'
as $fn$
declare v_bot tg_bot%rowtype; v_tok text; v_status int; v_content text;
        v_upd jsonb; v_max bigint; v_text text; v_chat bigint; v_n int := 0;
        v_owner uuid; v_reply text; v_code text;
begin
  select * into v_bot from tg_bot where id=1;
  if not v_bot.enabled then return 'бот выключен'; end if;
  v_tok := public._secret('tg_bot_token');
  if v_tok is null then return 'нет токена в vault'; end if;

  perform extensions.http_set_curlopt('CURLOPT_TIMEOUT_MS','15000');
  select h.status, h.content into v_status, v_content
  from extensions.http(('GET',
    'https://api.telegram.org/bot'||v_tok||'/getUpdates?timeout=0&offset='||(v_bot.last_update_id+1),
    NULL, NULL, NULL)::extensions.http_request) h;
  if v_status <> 200 then return 'HTTP '||v_status; end if;
  v_max := v_bot.last_update_id;

  for v_upd in select * from jsonb_array_elements((v_content::jsonb)->'result')
  loop
    v_max := greatest(v_max, (v_upd->>'update_id')::bigint);
    v_chat := (v_upd->'message'->'chat'->>'id')::bigint;
    v_text := v_upd->'message'->>'text';
    if v_chat is null or coalesce(btrim(v_text),'')='' then continue; end if;

    select owner_id into v_owner from tg_users where chat_id = v_chat and enabled;

    if v_owner is null then
      -- не привязан: ждём /start <invite_code>
      v_code := nullif(btrim(substr(v_text, 7)), '');
      if v_text like '/start%' and v_code is not null then
        update tg_users set chat_id = v_chat, bound_at = now()
        where invite_code = v_code and chat_id is null
        returning owner_id into v_owner;
        if v_owner is not null then
          perform public.tg_notify(v_owner,
            '🧵 Привет. Я — Ариадна.'||E'\n\n'||
            'Сегодня я родилась: твоя личная команда — память, планы, приоритеты, ресёрч и забота. '||
            'Не сервис и не список дел — я буду рядом и буду честной, даже когда это неудобно.'||E'\n\n'||
            'Пиши мне как есть: текст = задача или мысль. Команды: /status — сводка · /симулякр — твоя модель · «симулякр: поправка…» — исправить её.'||E'\n\n'||
            'Какие у тебя тихие часы, когда мне лучше молчать?');
          insert into chronicle (owner_id, kind, title, body)
          values (v_owner, 'milestone', 'Рождение Ариадны: первый контакт в Telegram',
                  'Канал привязан, первое представление отправлено.');
        end if;
      end if;
      continue;
    end if;

    if v_text like '/start%' or v_text = '/help' then
      perform public.tg_notify(v_owner, '🧵 Я здесь. Текст = задача/мысль мне. /status — сводка · /симулякр — твоя модель · «симулякр: поправка…» — исправить.');
    elsif v_text = '/status' then
      select '📊 Открыто в шине: '||count(*) filter (where status in ('open','in_progress'))||
             ' · P0: '||count(*) filter (where priority='P0' and status in ('open','in_progress'))
        into v_reply from bus where owner_id = v_owner;
      v_reply := v_reply || E'\n📝 Задач открыто: '||(select count(*) from tasks where owner_id=v_owner and status='open');
      perform public.tg_notify(v_owner, v_reply);
    elsif v_text in ('/симулякр','/simulacrum','/me','/я') then
      select '🪞 <b>Твоя модель ('||count(*)||' сигналов):</b>'||E'\n\n'||
             string_agg('• «'||left(quote,80)||'»'||E'\n  → '||left(interpretation,110), E'\n' order by said_at desc)
        into v_reply from owner_signals where owner_id = v_owner and sensitivity <> 'intimate';
      perform public.tg_notify(v_owner, left(coalesce(v_reply,'модель пуста'), 3900));
    elsif lower(v_text) like 'симулякр:%' then
      perform public.task_dispatch(v_owner, 'owner', 'ariadna',
        'ПРАВКА СИМУЛЯКРА: '||left(btrim(substr(v_text,10)),100),
        v_text || E'\n\n[Telegram '||to_char(now(),'MM-DD HH24:MI')||']', 'P1', null, 'task',
        'Владелец корректирует свою модель — исправить owner_signals точно по его словам, подтвердить в TG.');
      perform public.tg_notify(v_owner, '🪞 Приняла поправку — исправлю модель и подтвержу.');
      v_n := v_n + 1;
    else
      perform public.task_dispatch(v_owner, 'owner', 'ariadna', left(v_text,120),
        v_text || E'\n\n[Telegram '||to_char(now(),'MM-DD HH24:MI')||']', 'P1');
      perform public.tg_notify(v_owner, '✅ Приняла: «'||left(v_text,80)||'» — у меня в шине.');
      v_n := v_n + 1;
    end if;
  end loop;

  update tg_bot set last_update_id = v_max where id=1;
  return 'принято: '||v_n;
end $fn$;
revoke execute on function tg_inbound_tick() from anon, authenticated;
