#!/usr/bin/env bash
# Локальный прогон миграций и тестов безопасности на чистом Postgres.
# Запуск из корня проекта:  ./supabase/tests/run.sh
set -euo pipefail
cd "$(dirname "$0")/.."   # -> папка supabase/

# найти psql (в PATH или в стандартных местах Postgres.app / установщиков)
PSQL="$(command -v psql || true)"
if [ -z "$PSQL" ]; then
  for p in \
    /Applications/Postgres.app/Contents/Versions/latest/bin \
    /Applications/Postgres.app/Contents/Versions/18/bin \
    /Library/PostgreSQL/18/bin \
    /opt/homebrew/opt/postgresql@18/bin; do
    if [ -x "$p/psql" ]; then PSQL="$p/psql"; break; fi
  done
fi
if [ -z "$PSQL" ]; then echo "psql не найден. Запусти Postgres.app или добавь psql в PATH."; exit 1; fi

DB=repair_test
BASE="${PGDATABASE:-postgres}"

echo "== пересоздаю базу $DB =="
"$PSQL" -q -d "$BASE" -c "drop database if exists $DB" -c "create database $DB"

run() { "$PSQL" -q -v ON_ERROR_STOP=1 -d "$DB" -f "$1"; }

echo "== заглушка окружения Supabase =="
run tests/00_supabase_stub.sql
echo "== миграции по порядку =="
for f in migrations/*.sql; do echo "-- $f"; run "$f"; done
echo "== тесты-атаки =="
run tests/attacks.sql
