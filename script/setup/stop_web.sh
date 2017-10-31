#!/bin/sh

docker service scale web=0
docker service rm web
docker secret rm danboorus_env