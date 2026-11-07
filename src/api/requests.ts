import { supabase } from '@/lib/supabase';
import type { Request, RequestHistory, RequestStatus, Urgency } from '@/api/types';

// RLS сама отдаёт только видимые строки: диспетчеру — все, мастеру — его.
export async function fetchRequests(): Promise<Request[]> {
  const { data, error } = await supabase.from('requests').select('*').order('created_at', { ascending: false });
  if (error) throw error;
  return data as Request[];
}

export async function fetchRequest(id: string): Promise<Request> {
  const { data, error } = await supabase.from('requests').select('*').eq('id', id).single();
  if (error) throw error;
  return data as Request;
}

export async function fetchHistory(requestId: string): Promise<RequestHistory[]> {
  const { data, error } = await supabase
    .from('request_history')
    .select('*')
    .eq('request_id', requestId)
    .order('id');
  if (error) throw error;
  return data as RequestHistory[];
}

export async function createRequest(input: {
  address: string;
  description: string;
  urgency: Urgency;
  master_id: string;
}): Promise<Request> {
  const { data, error } = await supabase.from('requests').insert(input).select().single();
  if (error) throw error;
  return data as Request;
}

// Единственный способ сменить статус — RPC. Все правила проверяет база.
export async function changeRequestStatus(params: {
  requestId: string;
  to: RequestStatus;
  comment?: string | null;
  newMaster?: string | null;
}): Promise<Request> {
  const { data, error } = await supabase.rpc('change_request_status', {
    p_request_id: params.requestId,
    p_to: params.to,
    p_comment: params.comment ?? null,
    p_new_master: params.newMaster ?? null,
  });
  if (error) throw error;
  return data as Request;
}
