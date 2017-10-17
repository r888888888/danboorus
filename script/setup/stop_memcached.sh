#!/bin/sh

docker service scale memcached=0
docker service rm memcached
