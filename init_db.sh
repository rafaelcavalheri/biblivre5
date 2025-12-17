#!/bin/bash

DATA_DIR="./data"
mkdir -p $DATA_DIR
COMPOSE_FILE="docker-compose.yml"
INIT_COMPOSE_FILE="docker-compose.init.yml"
VOLUME_NAME="biblivre5-docker_biblivredb" # This is usually projectname_volumename

if [ -z "$(ls -A $DATA_DIR)" ]; then
  echo "Diretório de dados vazio. Inicializando o banco de dados..."

  # Step 1: Bring up the service with the init compose file to create and initialize the named volume
  echo "Iniciando contêiner temporário para inicializar o banco de dados..."
  docker-compose -f $COMPOSE_FILE -f $INIT_COMPOSE_FILE up -d biblivre

  # Wait for the database to initialize (adjust as needed)
  echo "Aguardando o banco de dados inicializar no volume nomeado..."
  sleep 30

  # Step 2: Find the mount point of the named volume
  VOLUME_MOUNTPOINT=$(docker volume inspect $VOLUME_NAME --format '{{ .Mountpoint }}')
  echo "Ponto de montagem do volume nomeado: $VOLUME_MOUNTPOINT"

  # Step 3: Copy data from the named volume to the local data directory
  echo "Copiando dados do volume nomeado para o diretório de dados local..."
  docker run --rm -v $VOLUME_MOUNTPOINT:/from -v $DATA_DIR:/to alpine ash -c "cp -a /from/. /to/"

  # Step 4: Bring down the service using the init compose file to remove the temporary named volume
  echo "Parando contêiner temporário e removendo volume nomeado..."
  docker-compose -f $COMPOSE_FILE -f $INIT_COMPOSE_FILE down -v

  echo "Inicialização do banco de dados concluída. Dados copiados para $DATA_DIR."
else
  echo "Diretório de dados já populado. Pulando a inicialização."
fi

# Step 5: Bring up the service with the main compose file
echo "Iniciando o serviço principal do biblivre..."
docker-compose -f $COMPOSE_FILE up -d biblivre
echo "Serviço Biblivre iniciado."