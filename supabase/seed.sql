-- Запускать ПОСЛЕ миграций и создания трёх пользователей в Authentication:
--   dispatcher@example.com, master1@example.com, master2@example.com
update public.profiles
set role = 'dispatcher',
full_name = 'Диспетчер Смирнова'
where
    email = 'dispatcher@example.com';

update public.profiles
set role = 'master',
full_name = 'Мастер Иванов'
where
    email = 'master1@example.com';

update public.profiles
set role = 'master',
full_name = 'Мастер Петров'
where
    email = 'master2@example.com';

do $$
declare
  d  uuid := (select id from public.profiles where email = 'dispatcher@example.com');
  m1 uuid := (select id from public.profiles where email = 'master1@example.com');
  m2 uuid := (select id from public.profiles where email = 'master2@example.com');
  r  uuid;
begin
  if d is null or m1 is null or m2 is null then
    raise exception 'Сначала создайте трёх пользователей в Authentication → Users';
  end if;

  -- «входим» диспетчером (true = только до конца скрипта)
  perform set_config('request.jwt.claims', json_build_object('sub', d)::text, true);

  -- 1. Новая
  insert into public.requests (address, description, urgency, master_id)
  values ('ул. Горького, 120, кв. 5', 'Течёт кран на кухне', 'normal', m1);

  -- 2. В работе
  insert into public.requests (address, description, urgency, master_id)
  values ('ул. Дзержинского, 45, подъезд 2', 'Не работает лифт', 'urgent', m1) returning id into r;
  perform set_config('request.jwt.claims', json_build_object('sub', m1)::text, true);
  perform public.change_request_status(r, 'in_progress');

  -- 3. Выполнена
  perform set_config('request.jwt.claims', json_build_object('sub', d)::text, true);
  insert into public.requests (address, description, urgency, master_id)
  values ('Ленинский пр., 30, кв. 12', 'Перегорела лампа в подъезде', 'normal', m1) returning id into r;
  perform set_config('request.jwt.claims', json_build_object('sub', m1)::text, true);
  perform public.change_request_status(r, 'in_progress');
  perform public.change_request_status(r, 'done');

  -- 4. Закрыта (полный цикл)
  perform set_config('request.jwt.claims', json_build_object('sub', d)::text, true);
  insert into public.requests (address, description, urgency, master_id)
  values ('ул. Горького, 120, кв. 8', 'Засор в ванной', 'normal', m2) returning id into r;
  perform set_config('request.jwt.claims', json_build_object('sub', m2)::text, true);
  perform public.change_request_status(r, 'in_progress');
  perform public.change_request_status(r, 'done');
  perform set_config('request.jwt.claims', json_build_object('sub', d)::text, true);
  perform public.change_request_status(r, 'closed');

  -- 5. Отказ → Новая со сменой мастера
  insert into public.requests (address, description, urgency, master_id)
  values ('ул. Дзержинского, 45, кв. 3', 'Нет отопления', 'urgent', m2) returning id into r;
  perform set_config('request.jwt.claims', json_build_object('sub', m2)::text, true);
  perform public.change_request_status(r, 'rejected', 'Нет доступа в квартиру, не открывают');
  perform set_config('request.jwt.claims', json_build_object('sub', d)::text, true);
  perform public.change_request_status(r, 'new', null, m1);
end $$;