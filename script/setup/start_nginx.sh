#!/bin/bash

DOCKER_HOST=sagiri
NGINX_SITES=/etc/nginx/conf.d

docker service create --name=nginx --mount="type=bind,src=$NGINX_SITES,dst=$NGINX_SITES" --replicas=1 --constraint="node.hostname == $DOCKER_HOST" --network=danboorunet --publish="80:80" --detach=true nginx
