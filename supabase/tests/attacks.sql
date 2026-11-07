-- =====================================================================
-- Тесты доступа «в обход интерфейса». Каждый шаг выполняется от роли
-- authenticated с JWT конкретного пользователя — как запрос из браузера.
-- Запуск: см. .gitlab-ci.yml (на каждый MR) или локально на чистом Postgres:
--   psql -f tests/00_supabase_stub.sql && миграции по порядку && psql -f tests/attacks.sql
-- =====================================================================
\set ON_ERROR_STOP on
\set QUIET on
\o /dev/null

-- Тестовые пользователи (в Supabase их создают в Dashboard → Authentication)
insert into auth.users (id, email, raw_user_meta_data, raw_app_meta_data) values
  ('00000000-0000-0000-0000-00000000000a', 'dispatcher@test.local', '{"full_name":"Диспетчер"}', '{"role":"dispatcher"}'),
  ('00000000-0000-0000-0000-00000000000b', 'master1@test.local',    '{"full_name":"Мастер 1"}',  '{}'),
  ('00000000-0000-0000-0000-00000000000c', 'master2@test.local',    '{"full_name":"Мастер 2"}',  '{"role":"master"}');

-- ---------- помощники ----------
create schema t;
grant usage on schema t to authenticated, anon;

create function t.ok(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is not true then raise exception 'FAIL: %', msg; end if;
  raise notice 'ok   %', msg;
end $$;

-- ждём, что запрос упадёт с ошибкой, текст которой содержит pattern
create function t.fails(q text, pattern text, msg text) returns void language plpgsql as $$
begin
  execute q;
  raise exception 'FAIL (запрос прошёл, а не должен был): %', msg;
exception when others then
  if sqlerrm like 'FAIL%' then raise; end if;
  if position(lower(pattern) in lower(sqlerrm)) = 0 then
    raise exception 'FAIL: % — неожиданная ошибка: %', msg, sqlerrm;
  end if;
  raise notice 'ok   % (%)', msg, sqlerrm;
end $$;

create function t.affected(q text) returns int language plpgsql as $$
declare n int; begin execute q; get diagnostics n = row_count; return n; end $$;

grant execute on all functions in schema t to authenticated, anon;

create function t.login(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, false);
$$;
grant execute on function t.login(text) to authenticated, anon;

\set D  '''00000000-0000-0000-0000-00000000000a'''
\set M1 '''00000000-0000-0000-0000-00000000000b'''
\set M2 '''00000000-0000-0000-0000-00000000000c'''

-- профили созданы триггером с верными ролями
select t.ok((select role from profiles where email='dispatcher@test.local') = 'dispatcher', 'диспетчер создан с ролью dispatcher');
select t.ok((select role from profiles where email='master1@test.local')    = 'master',     'по умолчанию роль master');

-- =====================================================================
\echo '--- Диспетчер'
select t.login(:D);
-- фиксированные id задаём служебной ролью (клиенту колонка id недоступна),
-- но с JWT диспетчера — чтобы сработали триггеры автора и истории
insert into requests (id, address, description, urgency, master_id) values
  ('20000000-0000-0000-0000-000000000001', 'ул. Ленина, 1',  'Течёт кран',    'normal', :M1),
  ('20000000-0000-0000-0000-000000000002', 'пр. Мира, 15',   'Не горит свет', 'urgent', :M2);

set role authenticated;
select t.ok((select status from requests where id='20000000-0000-0000-0000-000000000001') = 'new', 'заявка создаётся в статусе new');
select t.ok((select author_id from requests where id='20000000-0000-0000-0000-000000000001') = :D, 'автор проставлен автоматически');
select t.ok((select count(*) from request_history) = 2, 'создание заявок записано в историю');

select t.ok(t.affected($$ insert into requests (address, description, urgency, master_id)
                          values ('ул. Новая, 2','Проверка','normal','00000000-0000-0000-0000-00000000000b') $$) = 1,
  'диспетчер создаёт заявку через API');
select t.fails($$ insert into requests (address, description, urgency, master_id, status)
                  values ('x','y','normal','00000000-0000-0000-0000-00000000000b','done') $$,
               'permission denied', 'нельзя создать заявку сразу в нужном статусе');
select t.fails($$ insert into requests (address, description, urgency, master_id, author_id)
                  values ('x','y','normal','00000000-0000-0000-0000-00000000000b','00000000-0000-0000-0000-00000000000c') $$,
               'permission denied', 'нельзя подставить чужого автора');
select t.fails($$ update requests set status = 'done' $$,
               'permission denied', 'диспетчер не может сменить статус прямым UPDATE');
select t.fails($$ insert into requests (address, description, urgency, master_id)
                  values ('x','y','normal','00000000-0000-0000-0000-00000000000a') $$,
               'Назначить можно только', 'нельзя назначить мастером диспетчера');
select t.fails($$ select change_request_status('20000000-0000-0000-0000-000000000001', 'in_progress') $$,
               'только назначенный мастер', 'диспетчер не берёт заявку в работу за мастера');
select t.fails($$ select change_request_status('20000000-0000-0000-0000-000000000001', 'done') $$,
               'запрещён', 'new → done запрещён');

-- =====================================================================
\echo '--- Мастер 1: чужое не видно и не меняется'
select t.login(:M1);
select t.ok((select count(*) from requests where id='20000000-0000-0000-0000-000000000001') = 1, 'видит свою заявку');
select t.ok((select count(*) from requests where id='20000000-0000-0000-0000-000000000002') = 0, 'чужую заявку по id не получить');
select t.ok((select count(*) from request_history where request_id='20000000-0000-0000-0000-000000000002') = 0, 'историю чужой заявки не видит');

select t.ok(t.affected($$ update requests set address='взлом' where id='20000000-0000-0000-0000-000000000001' $$) = 0, 'не может редактировать даже свою заявку (RLS: 0 строк)');
select t.fails($$ update requests set status='in_progress' $$, 'permission denied', 'не может сменить статус прямым UPDATE');
select t.fails($$ update profiles set role='dispatcher' $$,    'permission denied', 'не может повысить себе роль');
select t.fails($$ insert into request_history (request_id, to_status, changed_by)
                  values ('20000000-0000-0000-0000-000000000001','done','00000000-0000-0000-0000-00000000000b') $$,
               'permission denied', 'нельзя вставить запись в историю');
select t.fails($$ update request_history set comment='подделка' $$, 'permission denied', 'нельзя изменить историю');
select t.fails($$ delete from request_history $$,                   'permission denied', 'нельзя удалить историю');

select t.fails($$ select change_request_status('20000000-0000-0000-0000-000000000002', 'in_progress') $$,
               'не найдена', 'не может двигать чужую заявку (и не узнаёт, что она есть)');
select t.fails($$ select change_request_status('20000000-0000-0000-0000-000000000001', 'done') $$,
               'запрещён', 'new → done (перепрыгнуть «в работе») запрещён');

-- =====================================================================
\echo '--- Полный честный цикл'
select change_request_status('20000000-0000-0000-0000-000000000001', 'in_progress');
select t.fails($$ select change_request_status('20000000-0000-0000-0000-000000000001', 'in_progress') $$,
               'уже в статусе', 'повторный переход в тот же статус отклоняется');
select change_request_status('20000000-0000-0000-0000-000000000001', 'done');
select t.fails($$ select change_request_status('20000000-0000-0000-0000-000000000001', 'closed') $$,
               'только диспетчер', 'мастер не закрывает заявку сам');
select t.login(:D);
select change_request_status('20000000-0000-0000-0000-000000000001', 'closed');
select t.fails($$ select change_request_status('20000000-0000-0000-0000-000000000001', 'in_progress') $$,
               'запрещён', 'из «Закрыта» никуда нельзя');

-- =====================================================================
\echo '--- Отказ и возврат со сменой мастера'
select t.login(:M2);
select t.fails($$ select change_request_status('20000000-0000-0000-0000-000000000002', 'rejected') $$,
               'причину', 'отказ без причины нельзя');
select change_request_status('20000000-0000-0000-0000-000000000002', 'rejected', 'Нет доступа в квартиру');

select t.login(:D);
select t.fails($$ select change_request_status('20000000-0000-0000-0000-000000000002', 'new') $$,
               'другого мастера', 'возврат из отказа без смены мастера нельзя');
select t.fails($$ select change_request_status('20000000-0000-0000-0000-000000000002', 'new', null, '00000000-0000-0000-0000-00000000000c') $$,
               'другого мастера', 'возврат на того же мастера нельзя');
select change_request_status('20000000-0000-0000-0000-000000000002', 'new', null, :M1);
select t.ok((select master_id from requests where id='20000000-0000-0000-0000-000000000002') = :M1, 'после возврата заявка у другого мастера');

-- =====================================================================
\echo '--- Возврат на доработку требует комментарий'
select t.login(:M1);
select change_request_status('20000000-0000-0000-0000-000000000002', 'in_progress');
select change_request_status('20000000-0000-0000-0000-000000000002', 'done');
select t.login(:D);
select t.fails($$ select change_request_status('20000000-0000-0000-0000-000000000002', 'in_progress') $$,
               'комментарий', 'возврат на доработку без комментария нельзя');
select change_request_status('20000000-0000-0000-0000-000000000002', 'in_progress', 'Переделать, подтёки');

-- =====================================================================
\echo '--- Без входа (anon)'
reset role;
set role anon;
select set_config('request.jwt.claims', '', false);
select t.fails($$ select * from requests $$,        'permission denied', 'anon не читает заявки');
select t.fails($$ select * from request_history $$, 'permission denied', 'anon не читает историю');
select t.fails($$ select change_request_status('20000000-0000-0000-0000-000000000001','new') $$,
               'permission denied', 'anon не может вызвать RPC');
reset role;

\echo ''
\echo 'ВСЕ ТЕСТЫ ПРОШЛИ'
