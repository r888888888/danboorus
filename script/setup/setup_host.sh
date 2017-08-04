#!/bin/sh

useradd danbooru -u 1000

mkdir -p /var/www/danbooru/shared/data/original
mkdir -p /var/www/danbooru/shared/data/preview
mkdir -p /var/www/danbooru/shared/data/sample
chown -R danbooru:danbooru /var/www/danbooru/shared
