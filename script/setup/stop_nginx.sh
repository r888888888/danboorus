#!/bin/sh

docker service scale nginx=0
docker service rm nginx
