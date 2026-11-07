import type { RequestStatus, Urgency } from '@/api/types';

export const STATUS_LABEL: Record<RequestStatus, string> = {
  new: 'Новая',
  in_progress: 'В работе',
  rejected: 'Отказ',
  done: 'Выполнена',
  closed: 'Закрыта',
};

export const STATUS_COLOR: Record<RequestStatus, string> = {
  new: 'default',
  in_progress: 'processing',
  rejected: 'error',
  done: 'success',
  closed: 'default',
};

export const URGENCY_LABEL: Record<Urgency, string> = {
  normal: 'Обычная',
  urgent: 'Срочная',
};
