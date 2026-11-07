create function public.is_dispatcher () returns boolean language sql stable security definer
set
    search_path = '' as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'dispatcher'
  );
$$;

create function public.transition_actor (
    p_from public.request_status,
    p_to public.request_status
) returns text language sql immutable
set
    search_path = '' as $$
  select case
    when p_from = 'new'         and p_to = 'in_progress' then 'assignee'
    when p_from = 'new'         and p_to = 'rejected'    then 'assignee'
    when p_from = 'rejected'    and p_to = 'new'         then 'dispatcher'
    when p_from = 'in_progress' and p_to = 'done'        then 'assignee'
    when p_from = 'done'        and p_to = 'closed'      then 'dispatcher'
    when p_from = 'done'        and p_to = 'in_progress' then 'dispatcher'
    else null
  end;
$$;

-- человекочитаемые названия статусов — для сообщений об ошибках
create function public.status_label (s public.request_status) returns text language sql immutable
set
    search_path = '' as $$
  select case s
    when 'new'         then 'Новая'
    when 'in_progress' then 'В работе'
    when 'rejected'    then 'Отказ'
    when 'done'        then 'Выполнена'
    when 'closed'      then 'Закрыта'
  end;
$$;

-- главный охранник: срабатывает при ЛЮБОМ обновлении заявки
create function public.requests_before_update () returns trigger language plpgsql security definer
set
    search_path = '' as $$
declare
  v_actor   text;
  v_comment text := nullif(trim(current_setting('app.status_comment', true)), '');
begin
  -- 1) неизменяемые поля — всегда возвращаем старое
  new.id         := old.id;
  new.author_id  := old.author_id;
  new.created_at := old.created_at;

  -- 2) если меняется мастер — он обязан иметь роль «master»
  if new.master_id is distinct from old.master_id and not exists (
    select 1 from public.profiles where id = new.master_id and role = 'master'
  ) then
    raise exception 'Назначить можно только пользователя с ролью «Мастер»'
      using errcode = '23514';
  end if;

  -- 3) всё про смену статуса — только если статус реально меняется
  if new.status is distinct from old.status then
    v_actor := public.transition_actor(old.status, new.status);

    -- 3a) такого перехода нет
    if v_actor is null then
      raise exception 'Переход «%» → «%» запрещён',
        public.status_label(old.status), public.status_label(new.status)
        using errcode = 'P0001';
    end if;

    -- 3b) переход мастера — только назначенный мастер
    if v_actor = 'assignee' and auth.uid() is distinct from old.master_id then
      raise exception 'Этот переход может сделать только назначенный мастер'
        using errcode = '42501';
    end if;

    -- 3c) переход диспетчера — только диспетчер
    if v_actor = 'dispatcher' and not public.is_dispatcher() then
      raise exception 'Этот переход может сделать только диспетчер'
        using errcode = '42501';
    end if;

    -- 3d) причина обязательна при отказе
    if new.status = 'rejected' and v_comment is null then
      raise exception 'При отказе нужно указать причину'
        using errcode = '23514';
    end if;

    -- 3e) комментарий обязателен при возврате на доработку
    if old.status = 'done' and new.status = 'in_progress' and v_comment is null then
      raise exception 'При возврате на доработку нужен комментарий'
        using errcode = '23514';
    end if;

    -- 3f) смена мастера vs статуса
    if old.status = 'rejected' and new.status = 'new' then
      -- особый случай: ТРЕБУЕМ назначить ДРУГОГО мастера
      if new.master_id is not distinct from old.master_id then
        raise exception 'При возврате из отказа нужно назначить другого мастера'
          using errcode = '23514';
      end if;
    elsif new.master_id is distinct from old.master_id then
      -- во всех прочих переходах менять мастера вместе со статусом нельзя
      raise exception 'Нельзя одновременно менять статус и мастера'
        using errcode = 'P0001';
    end if;
  end if;

  return new;
end;
$$;

create trigger requests_before_update before
update on public.requests for each row
execute function public.requests_before_update ();

create function public.requests_before_insert () returns trigger language plpgsql security definer
set
    search_path = '' as $$
begin
  -- нельзя создавать заявку без входа
  if auth.uid() is null then
    raise exception 'Не авторизован' using errcode = '42501';
  end if;

  -- форсируем честные значения независимо от того, что прислал клиент
  new.status     := 'new';
  new.author_id  := auth.uid();
  new.created_at := now();

  -- мастер должен быть реальным мастером
  if not exists (
    select 1 from public.profiles where id = new.master_id and role = 'master'
  ) then
    raise exception 'Назначить можно только пользователя с ролью «Мастер»'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger requests_before_insert before insert on public.requests for each row
execute function public.requests_before_insert ();

create function public.requests_write_history () returns trigger language plpgsql security definer
set
    search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    -- заявку только создали: из «ничего» в её первый статус
    insert into public.request_history (request_id, from_status, to_status, changed_by, comment)
    values (new.id, null, new.status, new.author_id, null);

  elsif new.status is distinct from old.status then
    -- статус сменился: записываем переход
    insert into public.request_history (request_id, from_status, to_status, changed_by, comment)
    values (
      new.id, old.status, new.status, auth.uid(),
      nullif(trim(current_setting('app.status_comment', true)), '')
    );
  end if;

  return null;
end;
$$;

create trigger requests_write_history
after insert
or
update on public.requests for each row
execute function public.requests_write_history ();

create function public.change_request_status (
    p_request_id uuid,
    p_to public.request_status,
    p_comment text default null,
    p_new_master uuid default null
) returns public.requests language plpgsql security definer
set
    search_path = '' as $$
declare
  v_request public.requests;
begin
  if auth.uid() is null then
    raise exception 'Не авторизован' using errcode = '42501';
  end if;

  -- находим заявку, которую пользователь вправе видеть
  select * into v_request from public.requests
  where id = p_request_id
    and (public.is_dispatcher() or master_id = auth.uid())
  for update;

  if not found then
    raise exception 'Заявка не найдена' using errcode = 'P0002';
  end if;

  if v_request.status = p_to then
    raise exception 'Заявка уже в статусе «%». Обновите страницу.', public.status_label(p_to)
      using errcode = 'P0001';
  end if;

  -- передаём комментарий в триггеры (true = только до конца транзакции)
  perform set_config('app.status_comment', coalesce(p_comment, ''), true);

  if p_new_master is not null then
    -- особый случай «Отказ → Новая»: меняем статус И мастера одним запросом
    update public.requests
      set status = p_to, master_id = p_new_master
      where id = p_request_id
      returning * into v_request;
  else
    update public.requests
      set status = p_to
      where id = p_request_id
      returning * into v_request;
  end if;

  perform set_config('app.status_comment', '', true);
  return v_request;
end;
$$;