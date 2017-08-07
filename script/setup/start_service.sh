#!/bin/bash

DOCKER_LABEL=web
DATA_DIR=/var/www/danbooru/shared/data
WEB_PORT=3000
REPLICAS=1

docker secret rm danboorus_env || true
docker secret create danboorus_env ~/config/danboorus_env
docker service create --name=web --mount="type=bind,src=$DATA_DIR,dst=$DATA_DIR" --publish=$WEB_PORT:$WEB_PORT --replicas=1 --network=danboorunet --secret=danboorus_env --constraint="node.labels.$DOCKER_LABEL == true" --env="RAILS_ENV=production" r888888888/danboorus sleep 1d
