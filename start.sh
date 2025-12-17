#!/bin/bash -e

if [ -n "$TZ" ]; then
  ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime || true
  echo "$TZ" > /etc/timezone || true
fi

mkdir -p /var/log/postgresql || true
chown -R postgres:postgres /var/lib/postgresql || true
su -s /bin/bash postgres -c '/usr/lib/postgresql/9.6/bin/pg_ctl -D /var/lib/postgresql/9.6/main -l /var/log/postgresql/postgresql-9.6.log start' || true

timeout_sec=30
for i in $(seq 1 $timeout_sec); do
  if su -s /bin/bash postgres -c "psql -U postgres -c 'SELECT 1' >/dev/null 2>&1"; then
    break
  fi
  sleep 1
done

exec /usr/local/tomcat/bin/catalina.sh run