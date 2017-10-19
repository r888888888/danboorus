#!/bin/sh

useradd danbooru -u 1000

mkdir -p /var/www/danbooru/shared/data/original
mkdir -p /var/www/danbooru/shared/data/preview
mkdir -p /var/www/danbooru/shared/data/sample
chown -R danbooru:danbooru /var/www/danbooru
cd ~
apt-get install git
git clone https://github.com/r888888888/danboorus.git
mkdir -p /var/log/web
chown -R danbooru:danbooru /var/log/web
