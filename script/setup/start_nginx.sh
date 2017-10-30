#!/bin/bash

DOCKER_HOST=sagiri
NGINX_SITES=/etc/nginx/conf.d
NGINX_SSL=/etc/nginx/ssl
LOG_DIR=/var/log/nginx
CACHE_DIR=/tmp/nginx-cache

docker service create --name=nginx --mount="type=bind,src=$NGINX_SSL,dst=$NGINX_SSL" --mount="type=bind,src=$NGINX_SITES,dst=$NGINX_SITES" --mount="type=bind,src=$LOG_DIR,dst=$LOG_DIR" --mount="type=bind,src=$CACHE_DIR,dst=$CACHE_DIR" --replicas=1 --constraint="node.hostname == $DOCKER_HOST" --network=danboorunet --publish="80:80" --publish="443:443" --detach=true nginx
