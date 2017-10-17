#!/bin/sh

docker service scale postgres=0
docker service rm postgres
