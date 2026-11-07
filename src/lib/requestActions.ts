import type { Profile, Request, RequestStatus } from '@/api/types';

export type RequestAction = {
  to: RequestStatus;
  label: string;
  needsComment: boolean;   // обязателен комментарий/причина
  needsNewMaster: boolean; // обязательно назначить другого мастера
  danger?: boolean;
};

type Rule = RequestAction & { from: RequestStatus; who: 'assignee' | 'dispatcher' };

// Зеркало правил из базы (transition_actor в 002_status_machine.sql) — ТОЛЬКО для показа кнопок.
// Настоящую проверку делает триггер: если таблицы разойдутся, база откажет, данные не испортятся.
const RULES: Rule[] = [
  { from: 'new',         to: 'in_progress', who: 'assignee',   label: 'Взять в работу',                 needsComment: false, needsNewMaster: false },
  { from: 'new',         to: 'rejected',    who: 'assignee',   label: 'Отказаться',                     needsComment: true,  needsNewMaster: false, danger: true },
  { from: 'rejected',    to: 'new',         who: 'dispatcher', label: 'Вернуть в работу (другой мастер)', needsComment: false, needsNewMaster: true },
  { from: 'in_progress', to: 'done',        who: 'assignee',   label: 'Выполнено',                      needsComment: false, needsNewMaster: false },
  { from: 'done',        to: 'closed',      who: 'dispatcher', label: 'Закрыть',                        needsComment: false, needsNewMaster: false },
  { from: 'done',        to: 'in_progress', who: 'dispatcher', label: 'Вернуть на доработку',           needsComment: true,  needsNewMaster: false, danger: true },
];

export function getAvailableActions(
  req: Pick<Request, 'status' | 'master_id'>,
  profile: Pick<Profile, 'id' | 'role'>,
): RequestAction[] {
  return RULES.filter((rule) => {
    if (rule.from !== req.status) return false;
    if (rule.who === 'dispatcher') return profile.role === 'dispatcher';
    return req.master_id === profile.id; // именно назначенный мастер, а не любой
  }).map(({ to, label, needsComment, needsNewMaster, danger }) => ({ to, label, needsComment, needsNewMaster, danger }));
}
