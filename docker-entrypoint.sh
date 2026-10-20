#!/bin/sh
set -e

if [ "${RUN_MIGRATIONS:-true}" = "true" ]; then
  echo "Running database migrations..."
  /app/bin/mini_task eval "MiniTask.Release.migrate"
fi

exec "$@"
