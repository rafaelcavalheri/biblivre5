#!/usr/bin/env bash
set -euo pipefail

# Garante que o script rode de um diretório válido
cd /tmp

# Adiciona caminhos comuns ao PATH para garantir que docker seja encontrado via sudo
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

# ==============================================================================
# Script de Backup Full do Biblivre 5 (Padrão .b5bz - ZIP)
# ==============================================================================

# --- Configurações ---

# Carrega variáveis do arquivo .env se existir
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
  source "$SCRIPT_DIR/.env"
fi

# Diretório de destino do backup (Prioridade: Argumento CLI > .env > Padrão)
DEST_DIR="${1:-${DEST_DIR:-/mnt/share06/BACKUP-BIB}}"
TIMESTAMP_FORMATTED="$(date +'%Y-%m-%d %Hh%Mm%Ss')"
BACKUP_NAME="Biblivre Backup ${TIMESTAMP_FORMATTED} Full"
# Remover espaços do timestamp para uso em nomes de arquivos temporários
TIMESTAMP_SAFE="${TIMESTAMP_FORMATTED// /_}"

# WORK_DIR é onde os arquivos (backup.meta, *.b5b) serão criados diretamente
WORK_DIR="/tmp/biblivre_backup_${TIMESTAMP_SAFE}"
CONTAINER_EXPORT_DIR="/tmp/export_${TIMESTAMP_SAFE}"
FINAL_ARCHIVE="${DEST_DIR}/${BACKUP_NAME}.b5bz"

# Credenciais do Banco de Dados
CONTAINER="${CONTAINER:-biblivre}"
PGUSER="${PGUSER:-biblivre}"
PGDB="${PGDB:-biblivre4}"
PGPASSWORD="${PGPASSWORD:-}"
PGHOST="${PGHOST:-127.0.0.1}"

if [ -z "$PGPASSWORD" ]; then
  echo "Erro: PGPASSWORD não definida. Crie um arquivo .env com as credenciais ou exporte a variável."
  exit 1
fi

# Função de limpeza para remover arquivos temporários
cleanup() {
    local exit_code=$?
    echo ""
    echo "[Cleanup] Verificando arquivos temporários..."
    
    # Remove diretório local temporário
    if [ -d "${WORK_DIR:-}" ]; then
        echo "  - Removendo diretório temporário local: $WORK_DIR"
        rm -rf "$WORK_DIR"
    fi

    # Remove diretório temporário no container (caso ainda exista)
    if [ -n "${CONTAINER_EXPORT_DIR:-}" ]; then
        if docker exec "$CONTAINER" test -d "$CONTAINER_EXPORT_DIR" 2>/dev/null; then
            echo "  - Removendo diretório temporário no container: $CONTAINER_EXPORT_DIR"
            docker exec "$CONTAINER" rm -rf "$CONTAINER_EXPORT_DIR"
        fi
    fi
    
    if [ $exit_code -ne 0 ]; then
        echo "[Cleanup] Backup finalizado com erro (código $exit_code)."
    fi
}
# Registra a função cleanup para ser executada ao sair (sucesso ou erro)
trap cleanup EXIT INT TERM

# --- Verificações Iniciais ---
if [ ! -d "$DEST_DIR" ]; then
    echo "Criando diretório de destino: $DEST_DIR"
    mkdir -p "$DEST_DIR"
fi

# Verificar se o container está rodando usando inspect (mais robusto que grep)
if ! docker inspect -f '{{.State.Running}}' "$CONTAINER" >/dev/null 2>&1; then
    echo "Erro: Container '$CONTAINER' não encontrado ou parado."
    echo "Lista de containers ativos:"
    docker ps --format "table {{.Names}}\t{{.Status}}"
    exit 1
fi
IS_RUNNING=$(docker inspect -f '{{.State.Running}}' "$CONTAINER")
if [ "$IS_RUNNING" != "true" ]; then
     echo "Erro: Container '$CONTAINER' existe mas não está rodando (Status: $IS_RUNNING)."
     exit 1
fi

echo "=================================================="
echo "Iniciando Backup do Biblivre: $BACKUP_NAME"
echo "Destino: $FINAL_ARCHIVE"
echo "=================================================="

# Criar estrutura de diretórios temporária
mkdir -p "$WORK_DIR/single"
echo "[1/6] Diretório de trabalho criado: $WORK_DIR"

# --- 1. Geração dos Dumps SQL ---
echo "[2/6] Gerando dumps SQL..."

# Função auxiliar para rodar pg_dump via docker
run_pg_dump() {
    local args="$1"
    local output_file="$2"
    docker exec -e PGPASSWORD="$PGPASSWORD" "$CONTAINER" pg_dump -h "$PGHOST" -U "$PGUSER" -d "$PGDB" $args -O -x > "$output_file"
}

# 1.1 Global Schema e Data (Apenas schemas 'global' e 'public', excluindo outras bibliotecas como 'hermeroteca')
echo "  - Exportando Global Schema (global, public)..."
run_pg_dump "-n global -n public -s" "$WORK_DIR/global.schema.b5b"

echo "  - Exportando Global Data (global, public)..."
run_pg_dump "-n global -n public -a" "$WORK_DIR/global.data.b5b"

# 1.2 Single Schema
echo "  - Exportando Single Schema..."
run_pg_dump "-n single -s" "$WORK_DIR/single.schema.b5b"

# 1.3 Single Data (Excluindo a tabela de mídias)
echo "  - Exportando Single Data (sem mídias)..."
run_pg_dump "-n single -a -T single.digital_media" "$WORK_DIR/single.data.b5b"

# 1.4 Single Media Metadata
echo "  - Exportando Metadados de Mídia..."
run_pg_dump "-n single -a -t single.digital_media" "$WORK_DIR/single.media.b5b"

# --- 2. Extração de Mídias Digitais (Large Objects) ---
echo "[3/6] Extraindo arquivos de mídia digital do banco..."

# Criar diretório temporário DENTRO do container
docker exec "$CONTAINER" mkdir -p "$CONTAINER_EXPORT_DIR"
docker exec "$CONTAINER" chmod 777 "$CONTAINER_EXPORT_DIR"

# Query SQL para exportar
SQL_EXPORT="SELECT lo_export(blob, '${CONTAINER_EXPORT_DIR}/' || id || '_' || regexp_replace(name, '[^a-zA-Z0-9.-]', '_', 'g')) FROM single.digital_media;"

echo "  - Executando lo_export no container..."
docker exec -e PGPASSWORD="$PGPASSWORD" "$CONTAINER" psql -h "$PGHOST" -U "$PGUSER" -d "$PGDB" -c "$SQL_EXPORT" > /dev/null

echo "  - Copiando arquivos extraídos do container..."
docker cp "${CONTAINER}:${CONTAINER_EXPORT_DIR}/." "$WORK_DIR/single/"

# Contar arquivos extraídos
NUM_FILES=$(ls -1 "$WORK_DIR/single/" | wc -l)
echo "  - $NUM_FILES arquivos de mídia recuperados."

# Limpar diretório temporário no container
docker exec "$CONTAINER" rm -rf "$CONTAINER_EXPORT_DIR"

# --- 3. Criação do backup.meta ---
echo "[4/6] Gerando arquivo de metadados (backup.meta)..."
# Data no formato ISO 8601 compatível
ISO_DATE=$(date +'%Y-%m-%dT%H:%M:%S.000%z')

cat > "$WORK_DIR/backup.meta" <<EOF
{"valid":false,"created":"${ISO_DATE}","schemas":{"single":{"left":"BIBLIOTECA PÚBLICA MOGI MIRIM","right":"Software Livre Gestão Bibliotecas"},"global":{"left":"Biblivre V","right":"Software Livre para Gestão de Bibliotecas"}},"backup_scope":"single_schema_from_multi_schema","type":"full"}
EOF

# --- 4. Compactação (ZIP) ---
echo "[5/6] Compactando arquivo final (.b5bz)..."
CURRENT_DIR=$(pwd)
# Entra no diretório de trabalho para compactar o conteúdo na raiz do arquivo
cd "$WORK_DIR"

# Garantir permissões legíveis para todos (evita problemas ao restaurar em outro servidor)
chmod -R a+rX .

# Zip recursivo (-r), silencioso (-q) e SEM entradas de diretório (-D) para compatibilidade com o Java do Biblivre
zip -r -q -D "$FINAL_ARCHIVE" .

cd "$CURRENT_DIR"

# --- 5. Limpeza (Gerenciada pelo trap cleanup) ---
echo "[6/6] Finalizando..."

echo "=================================================="
echo "Backup concluído com sucesso!"
echo "Arquivo gerado: $FINAL_ARCHIVE"
echo "Tamanho: $(du -h "$FINAL_ARCHIVE" | cut -f1)"
echo "=================================================="
