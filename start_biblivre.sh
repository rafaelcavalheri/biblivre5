#!/bin/bash
set -e

# Comandos originais de permissão
echo "Ajustando permissões do PostgreSQL..."
chown -Rf postgres /var/lib/postgresql/9.6/main
chmod -R 700 /var/lib/postgresql/9.6/main

# Iniciar PostgreSQL
echo "Iniciando serviço PostgreSQL..."
service postgresql start

# Aguardar o PostgreSQL estar pronto
echo "Aguardando PostgreSQL aceitar conexões..."
until su - postgres -c "psql -c '\l'" > /dev/null 2>&1; do
  echo "Postgres indisponível - aguardando..."
  sleep 2
done

# Verificar se o banco precisa ser inicializado
echo "Verificando estado do banco de dados biblivre4..."
# Verifica se a tabela 'logins' existe no schema 'global'
TABLE_EXISTS=$(su - postgres -c "psql -d biblivre4 -tAc \"SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'global' AND table_name = 'logins');\"")

if [ "$TABLE_EXISTS" = "f" ] || [ -z "$TABLE_EXISTS" ]; then
    echo "Banco de dados vazio detectado. Iniciando processo de importação..."
    
    # Tenta encontrar o SQL em locais conhecidos, priorizando Biblivre5
    SQL_FILE=""
    if [ -f "/usr/local/tomcat/webapps/Biblivre5/biblivre_global_4.0.0.sql" ]; then
        SQL_FILE="/usr/local/tomcat/webapps/Biblivre5/biblivre_global_4.0.0.sql"
    elif [ -f "/usr/local/tomcat/webapps/Biblivre4/biblivre_global_4.0.0.sql" ]; then
        SQL_FILE="/usr/local/tomcat/webapps/Biblivre4/biblivre_global_4.0.0.sql"
    fi
    
    if [ ! -z "$SQL_FILE" ]; then
        echo "Importando schema inicial de $SQL_FILE..."
        # Redireciona output para evitar flood de logs, mas mostra erros
        su - postgres -c "psql -d biblivre4 -f $SQL_FILE" > /tmp/import_log 2>&1
        if [ $? -eq 0 ]; then
             echo "Importação realizada com sucesso."
        else
             echo "AVISO: Ocorreram erros durante a importação (verifique /tmp/import_log). Isso pode ser normal se houver duplicatas parciais."
             cat /tmp/import_log | head -n 20
        fi
        
        echo "Configurando search_path do usuário biblivre..."
        su - postgres -c "psql -c 'ALTER USER biblivre SET search_path TO global, public;'"
        
        echo "Inicialização do banco de dados concluída."
    else
        echo "ERRO CRÍTICO: Arquivo SQL não encontrado em $SQL_FILE. O banco permanecerá vazio."
    fi
else
    echo "Banco de dados já está populado. Pulando importação."
    # Garante que o search_path esteja correto mesmo se o banco já existir
    su - postgres -c "psql -c 'ALTER USER biblivre SET search_path TO global, public;'"
fi

# Configurar senha no context.xml para TODAS as aplicações encontradas
if [ ! -z "$POSTGRES_PASSWORD" ]; then
    echo "Atualizando senha do banco em todos os context.xml encontrados..."
    find /usr/local/tomcat/webapps -name "context.xml" | while read CONTEXT_XML; do
        echo "Atualizando $CONTEXT_XML..."
        sed -i "s/password=\"[^\"]*\"/password=\"$POSTGRES_PASSWORD\"/g" "$CONTEXT_XML"
    done
fi

# Iniciar Tomcat
echo "Iniciando Tomcat (Biblivre)..."
exec catalina.sh run
