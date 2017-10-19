#!/bin/sh

docker build -f script/setup/Dockerfile.postgres -t r888888888/postgres .
docker push r888888888/postgres
