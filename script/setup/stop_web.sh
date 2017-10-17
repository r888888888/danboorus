#!/bin/sh

docker service scale web=0
docker service rm web
