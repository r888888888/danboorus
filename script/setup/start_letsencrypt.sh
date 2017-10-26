#!/bin/bash

DOCKER_HOST=sagiri
NGINX_SSL_CERTS=/etc/nginx/ssl
LOG_DIR=/var/log/nginx

docker service create --name=letsencrypt --mount="type=bind,src=$NGINX_SSL_CERTS,dst=$NGINX_SSL_CERTS" --replicas=1 --constraint="node.hostname == $DOCKER_HOST" --network=danboorunet --detach=true jrcs/letsencrypt-nginx-proxy-companion
