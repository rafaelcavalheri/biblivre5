# Biblivre5 Docker

Este projeto configura o Biblivre5 v5.1.31 usando Docker com volumes persistentes, ja corrigido o bug no horario de empréstimos com 1h a menos da versão oficial

## Componentes

- **PostgreSQL**: Banco de dados para o Biblivre5
- **Tomcat7**: Servidor de aplicação para o Biblivre5

## Volumes Persistentes

- **postgres_data**: Armazena os dados do PostgreSQL
- **tomcat_data**: Armazena os arquivos da aplicação Tomcat

## Como usar

1. Certifique-se de ter o Docker e o Docker Compose instalados
2. Execute o comando abaixo para iniciar os contêineres:

```bash
docker-compose up -d
```

3. Acesse o Biblivre5 em: http://localhost:9050/Biblivre5

## Para parar os contêineres

```bash
docker-compose down
```

## Persistência dos Dados

- Os dados do Postgres são persistidos em ` /dados/biblivre-db ` no host, montados em ` /var/lib/postgresql/9.6/main ` no container.
- Os artefatos da aplicação são montados a partir de ` ./webapps ` para ` /usr/local/tomcat/webapps `.

### Recriar em Outro Servidor (banco novo)

1. Preparar a pasta de dados:
   - `sudo mkdir -p /dados/biblivre-db`
   - `sudo chown -R 103:105 /dados/biblivre-db`
   - `sudo chmod 700 /dados/biblivre-db`
2. Copiar este diretório de projeto (incluindo `docker-compose.yml` e `webapps`) para o novo servidor em ` /dados/biblivre5-docker `.
3. Subir os serviços:
   - `cd /dados/biblivre5-docker`
   - `docker-compose up -d`
4. Verificar:
   - `docker inspect -f '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}' biblivre`
   - `docker logs biblivre`

### Migrar com Dados Existentes

1. No novo servidor, criar e preparar a pasta:
   - `sudo mkdir -p /dados/biblivre-db`
2. Transferir os dados do servidor antigo para ` /dados/biblivre-db ` (ex.: `scp -r`):
   - `scp -r <usuario>@<host_antigo>:/dados/biblivre-db/* /dados/biblivre-db/`
3. Ajustar permissões (a imagem usa `uid=103` e `gid=105` para o usuário `postgres`):
   - `sudo chown -R 103:105 /dados/biblivre-db`
   - `sudo chmod 700 /dados/biblivre-db`
4. Subir os serviços:
   - `cd /dados/biblivre5-docker`
   - `docker-compose up -d`

> Dica: para confirmar `uid/gid` do `postgres` na imagem, execute:
>
> `docker run --rm --entrypoint /bin/bash faelcavalheri/biblivre5-docker:latest -lc 'id -u postgres; id -g postgres'`
