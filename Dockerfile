FROM ruby:2.3.1

# this builds the danbooru docker container. note that this is only
# for the web process; you will need to run a docker image for postgres,
# memcached, and the delayed job workers separately.

RUN apt-get update
RUN apt-get -y install apt-utils build-essential automake libssl-dev libxml2-dev libxslt-dev ncurses-dev sudo libreadline-dev flex bison ragel memcached libmemcached-dev git curl libcurl4-openssl-dev imagemagick libmagickcore-dev libmagickwand-dev sendmail-bin sendmail postgresql-client libpq-dev nginx ssh coreutils ffmpeg mkvtoolnix emacs24-nox
RUN useradd -ms /bin/bash danbooru -u 1000
RUN mkdir /app
COPY . /app
RUN chown -R danbooru:danbooru /app
EXPOSE 3000
USER danbooru
ENV RAILS_ENV production
RUN echo 'export RAILS_ENV=production' >> ~/.profile
RUN echo 'gem: --no-document' > ~/.gemrc
RUN gem install bundler
WORKDIR /app
RUN bundle install
CMD ["bundle", "exec", "unicorn", "-p", "3000", "-c", "config/unicorn/unicorn.rb"]
