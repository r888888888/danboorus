#!/bin/sh

docker service scale job=0
docker service rm job
docker secret rm danboorus_env