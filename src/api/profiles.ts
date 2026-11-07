import { supabase } from '@/lib/supabase';
import type { Profile } from '@/api/types';

export async function fetchProfile(id: string): Promise<Profile> {
  const { data, error } = await supabase.from('profiles').select('*').eq('id', id).single();
  if (error) throw error;
  return data as Profile;
}

// Все профили (RLS разрешает вошедшим видеть друг друга) — для имён и списка мастеров.
export async function fetchAllProfiles(): Promise<Profile[]> {
  const { data, error } = await supabase.from('profiles').select('*').order('full_name');
  if (error) throw error;
  return data as Profile[];
}
