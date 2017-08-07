#!/bin/sh

useradd danbooru -u 1000

mkdir -p /var/www/danbooru/shared/data
chown -R danbooru:danbooru /var/www/danbooru
