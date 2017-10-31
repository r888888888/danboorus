#!/bin/bash

DOCKER_HOST=sagiri
LOG_DIR=/var/log/nginx
CACHE_DIR=/tmp/nginx-cache

docker config create nginx-danbooru-conf ~/danboorus/script/setup/web_nginx_conf
docker config create nginx-ssl-danboor-us-bundle ~/config/danboor-us-bundle.crt
docker config create nginx-ssl-danboor-us-key ~/config/danbooru-us.key
docker service create \
  --name=nginx \
  --mount="type=bind,src=$LOG_DIR,dst=$LOG_DIR" \
  --mount="type=bind,src=$CACHE_DIR,dst=$CACHE_DIR" \
  --config="source=nginx-ssl-danboor-us-bundle,target=/etc/nginx/conf.d/danboor-us-bundle.crt" \
  --config="source=nginx-ssl-danboor-us-key,target=/etc/nginx/conf.d/danboor-us.key" \
  --config="source=nginx-danbooru-conf,target=/etc/nginx/sites-enabled/danboor-us.conf" \
  --replicas=1 \
  --constraint="node.hostname == $DOCKER_HOST" \
  --network=danboorunet \
  --publish="80:80" \
  --publish="443:443" \
  --detach=true \
  nginx
