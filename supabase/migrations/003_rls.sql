-- Supabase по умолчанию выдаёт anon/authenticated все права на новые таблицы. Забираем всё.
revoke all on public.profiles,
public.requests,
public.request_history
from
    anon,
    authenticated;

-- profiles: только чтение (имена в карточках и в истории)
grant
select
    on public.profiles to authenticated;

-- requests: чтение и удаление (строки отфильтрует RLS); запись — только в безопасные колонки
grant
select
,
    delete on public.requests to authenticated;

grant insert (address, description, urgency, master_id),
update (address, description, urgency, master_id) on public.requests to authenticated;

-- request_history: только чтение. insert/update/delete не выдаём ВООБЩЕ.
grant
select
    on public.request_history to authenticated;

-- Функции: Supabase по умолчанию даёт EXECUTE всем (включая anon). Наводим порядок.
revoke
execute on function public.change_request_status (uuid, public.request_status, text, uuid)
from
    public,
    anon;

grant
execute on function public.change_request_status (uuid, public.request_status, text, uuid) to authenticated;

revoke
execute on function public.is_dispatcher ()
from
    public,
    anon;

grant
execute on function public.is_dispatcher () to authenticated;

revoke
execute on function public.status_label (public.request_status)
from
    anon;

revoke
execute on function public.transition_actor (public.request_status, public.request_status)
from
    anon;

revoke
execute on function public.handle_new_user ()
from
    public,
    anon,
    authenticated;

revoke
execute on function public.requests_before_insert ()
from
    public,
    anon,
    authenticated;

revoke
execute on function public.requests_before_update ()
from
    public,
    anon,
    authenticated;

revoke
execute on function public.requests_write_history ()
from
    public,
    anon,
    authenticated;

-- включаем RLS на всех таблицах
alter table public.profiles enable row level security;

alter table public.requests enable row level security;

alter table public.request_history enable row level security;

-- PROFILES: все вошедшие видят друг друга (имена и роли — для карточек и истории)
create policy profiles_select on public.profiles for
select
    to authenticated using (true);

-- REQUESTS --------------------------------------------------------
-- кто видит: диспетчер — все заявки, мастер — только свои
create policy requests_select on public.requests for
select
    to authenticated using (
        public.is_dispatcher ()
        or master_id = (
            select
                auth.uid ()
        )
    );

-- кто создаёт: только диспетчер
create policy requests_insert on public.requests for insert to authenticated
with
    check (public.is_dispatcher ());

-- кто редактирует напрямую (адрес/описание/срочность/мастер): только диспетчер
create policy requests_update on public.requests for
update to authenticated using (public.is_dispatcher ())
with
    check (public.is_dispatcher ());

-- кто удаляет: только диспетчер
create policy requests_delete on public.requests for delete to authenticated using (public.is_dispatcher ());

-- REQUEST_HISTORY: видно тем, кто видит заявку. Политик на запись НЕТ => запись запрещена.
create policy request_history_select on public.request_history for
select
    to authenticated using (
        public.is_dispatcher ()
        or exists (
            select
                1
            from
                public.requests r
            where
                r.id = request_history.request_id
                and r.master_id = (
                    select
                        auth.uid ()
                )
        )
    );