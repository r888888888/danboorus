docker exec -it `docker container ls -f 'name=web' -q` bundle exec rake db:migrate
