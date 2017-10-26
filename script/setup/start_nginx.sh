#!/bin/bash

DOCKER_HOST=sagiri
NGINX_SITES=/etc/nginx/conf.d
NGINX_SSL_CERTS=/etc/nginx/ssl
LOG_DIR=/var/log/nginx

docker service create --name=nginx --mount="type=bind,src=$NGINX_SSL_CERTS,dst=$NGINX_SSL_CERTS" --mount="type=bind,src=$NGINX_SITES,dst=$NGINX_SITES" --mount="type=bind,src=$LOG_DIR,dst=$LOG_DIR" --replicas=1 --constraint="node.hostname == $DOCKER_HOST" --network=danboorunet --publish="80:80" --publish="443:443" --detach=true nginx
