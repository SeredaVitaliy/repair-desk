// Типы фронта — зеркало схемы базы (001_schema.sql).

export type AppRole = 'dispatcher' | 'master';

export type RequestStatus = 'new' | 'in_progress' | 'rejected' | 'done' | 'closed';

export type Urgency = 'normal' | 'urgent';

export type Profile = {
  id: string;
  email: string;
  full_name: string;
  role: AppRole;
  created_at: string;
};

export type Request = {
  id: string;
  address: string;
  description: string;
  urgency: Urgency;
  master_id: string;
  status: RequestStatus;
  author_id: string;
  created_at: string;
};

export type RequestHistory = {
  id: number;
  request_id: string;
  from_status: RequestStatus | null;
  to_status: RequestStatus;
  changed_by: string;
  comment: string | null;
  created_at: string;
};
