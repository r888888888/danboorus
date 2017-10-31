#!/bin/sh

docker service scale nginx=0
docker service rm nginx
docker config rm nginx-ssl-danboor-us-key
docker config rm nginx-ssl-danboor-us-bundle
docker config rm nginx-danbooru-conf
