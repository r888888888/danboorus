#!/bin/sh

docker build -t r888888888/danboorus -f script/setup/Dockerfile.web .
docker push r888888888/danboorus