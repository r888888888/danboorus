#!/bin/bash

DOCKER_LABEL=web
DATA_DIR=/var/www/danbooru/shared/data
LOG_DIR=/var/log/web
WEB_PORT=3000
REPLICAS=1

docker secret create danboorus_env ~/config/danboorus_env
docker service create \
  --name=web \
  --mount="type=bind,src=$DATA_DIR,dst=$DATA_DIR" \
  --mount="type=bind,src=$LOG_DIR,dst=$LOG_DIR" \
  --mount="type=bind,src=$LOG_DIR,dst=/app/log" \
  --publish=$WEB_PORT:$WEB_PORT \
  --replicas=$REPLICAS \
  --network=danboorunet \
  --secret=danboorus_env \
  --constraint="node.labels.$DOCKER_LABEL == true" \
  --env="RAILS_ENV=production" \
  --detach=true \
  r888888888/danboorus \
  bundle exec unicorn -c config/unicorn/production.rb
