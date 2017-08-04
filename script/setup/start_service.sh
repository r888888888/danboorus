#!/bin/bash

DOCKER_LABEL=web
DATA_DIR=/var/www/danbooru/shared/data
WEB_PORT=3000

docker service create --name=web --mount="type=bind,src=$DATA_DIR,dst=$DATA_DIR" --publish=$WEB_PORT:$WEB_PORT --replicas=1 --network=danboorunet --secret=danboorus_env --constraint="node.labels.$DOCKER_LABEL == true" --env="RAILS_ENV=production" danboorus:latest
