#!/usr/bin/env bash
set -euo pipefail
[ "${EUID:-$(id -u)}" -eq 0 ] || { echo "Execute com sudo"; exit 1; }

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# --- CONFIGURAÇÃO ---
# Altere as variáveis abaixo conforme seu ambiente
DEST="/caminho/para/backup"        # Diretório onde os CSVs serão salvos
CONTAINER="biblivre"               # Nome do container Docker
PGUSER="biblivre"                  # Usuário do banco de dados
PGDB="biblivre4"                   # Nome do banco de dados
PGPASSWORD="SUA_SENHA_AQUI"        # Senha do banco de dados
PGHOST="${PGHOST:-127.0.0.1}"
SQL_HOST_DIR="./biblivre-sql"      # Caminho para os scripts SQL no host
SQL_CONTAINER_DIR="/opt/biblivre/sql" # Caminho para os scripts SQL dentro do container
# --------------------

TS="$(date +%Y-%m-%d_%H%M)"

# Verifica se o diretório de destino existe
if [ ! -d "$DEST" ]; then
  echo "Diretório de destino não encontrado: $DEST"
  echo "Por favor, crie o diretório ou ajuste a variável DEST no script."
  exit 1
fi

command -v docker >/dev/null 2>&1 || { echo "Docker não encontrado no PATH"; exit 1; }

archive_old_csvs() {
  local odir="$DEST/old"
  mkdir -p "$odir"
  find "$DEST" -maxdepth 1 -type f -name '*.csv' -print0 | xargs -0 -r mv -t "$odir"
}

prune_old_csvs() {
  local odir="$DEST/old"
  [ -d "$odir" ] || return 0
  find "$odir" -type f -name '*.csv' -mtime +7 -print0 | xargs -0 -r rm -f
}

run() {
  local base="$1"
  local out="$2"
  local tmp_out
  tmp_out="$(mktemp "/tmp/${base}_${TS}.XXXXXX.tmp")"
  local host_file="${SQL_HOST_DIR}/${base}.sql"
  local container_file="${SQL_CONTAINER_DIR}/${base}.sql"
  
  if [ -f "$host_file" ]; then
    docker exec -i -e PGPASSWORD="$PGPASSWORD" "$CONTAINER" psql -v ON_ERROR_STOP=1 -h "$PGHOST" -U "$PGUSER" -d "$PGDB" -f - < "$host_file" > "$tmp_out"
    mv "$tmp_out" "$out"
    return
  fi
  
  if docker exec "$CONTAINER" test -f "$container_file"; then
    docker exec -e PGPASSWORD="$PGPASSWORD" "$CONTAINER" psql -v ON_ERROR_STOP=1 -h "$PGHOST" -U "$PGUSER" -d "$PGDB" -f "$container_file" > "$tmp_out"
    mv "$tmp_out" "$out"
    return
  fi
  
  echo "Arquivo SQL não encontrado: $host_file ou $container_file" >&2
  exit 1
}

archive_old_csvs
prune_old_csvs

run biblio_holdings "$DEST/biblioholdings_${TS}.csv"
run lending_fines   "$DEST/lending_fines_${TS}.csv"
run consulta        "$DEST/biblivre_${TS}.csv"
run lendings        "$DEST/lendings_${TS}.csv"

#docker exec -i -e PGPASSWORD="$PGPASSWORD" "$CONTAINER" pg_dump -h "$PGHOST" -U "$PGUSER" -d "$PGDB" -F c > "$DEST/${PGDB}_${TS}.dump"
