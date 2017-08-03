#!/bin/bash

DOCKER_LABEL=web
DATA_DIR=/var/www/danbooru/shared/data
WEB_PORT=3000

docker service create --name=postgres --mount="type=bind,src=$DATA_DIR,dst=$DATA_DIR" --publish=$WEB_PORT:$WEB_PORT --replicas=1 --constraint="node.label == $DOCKER_LABEL" --env="RAILS_ENV=production" danboorus:latest
