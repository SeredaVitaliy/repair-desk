import { createClient } from '@supabase/supabase-js';

const url = import.meta.env.VITE_SUPABASE_URL;
const key = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!url || !key) {
  throw new Error('Не заданы VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY (см. .env.example)');
}

// Во фронте только публичный ключ. Он безопасен: сам по себе ничего не разрешает,
// все права проверяет база (RLS + гранты + триггеры).
export const supabase = createClient(url, key);
