import { Tag } from 'antd';
import type { RequestStatus } from '@/api/types';
import { STATUS_COLOR, STATUS_LABEL } from '@/lib/statuses';

export function StatusTag({ status }: { status: RequestStatus }) {
  return <Tag color={STATUS_COLOR[status]}>{STATUS_LABEL[status]}</Tag>;
}
