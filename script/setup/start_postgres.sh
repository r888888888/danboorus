#!/bin/bash

# define in your env
#PG_PASS=
DOCKER_HOST=elf
PG_DATA=/var/lib/postgresql/data

docker service create \
  --name=postgres \
  --mount="type=bind,src=$PG_DATA,dst=$PG_DATA" \
  --publish=5432:5432 \
  --replicas=1 \
  --constraint="node.hostname == $DOCKER_HOST" \
  --env="POSTGRES_PASSWORD=$PG_PASS" \
  --network=danboorunet \
  --detach=true \
  r888888888/postgres:latest
