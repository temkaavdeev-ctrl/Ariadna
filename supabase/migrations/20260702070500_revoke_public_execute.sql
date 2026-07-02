-- Урок: revoke from anon недостаточно — EXECUTE по умолчанию у PUBLIC. Снимаем у всех органов.
revoke execute on function my_owner_id() from public, anon, authenticated;
revoke execute on function _secret(text) from public, anon, authenticated;
revoke execute on function task_dispatch(uuid,text,text,text,text,text,text[],text,text) from public, anon, authenticated;
revoke execute on function task_close(uuid,text,text,text,boolean,text,text[]) from public, anon, authenticated;
revoke execute on function tg_notify(uuid,text) from public, anon, authenticated;
revoke execute on function tg_inbound_tick() from public, anon, authenticated;
revoke execute on function tg_digest_tick() from public, anon, authenticated;
revoke execute on function voyage_embed(text[],text) from public, anon, authenticated;
revoke execute on function mem_embed_tick() from public, anon, authenticated;
revoke execute on function owner_check(uuid,text,int) from public, anon, authenticated;
revoke execute on function mem_recall(uuid,text,int) from public, anon, authenticated;
revoke execute on function apoptosis_tick() from public, anon, authenticated;
-- и на будущее: новые функции не получают EXECUTE автоматически
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;
