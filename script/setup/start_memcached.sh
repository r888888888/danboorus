#!/bin/bash

docker service create --name=memcached --publish=11211:11211 --replicas=1 --network=danboorunet --constraint="node.labels.web == true" --detach=true memcached:1.5-alpine memcached -m 64
