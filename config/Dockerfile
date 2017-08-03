FROM ruby:2.3.1

RUN apt-get update
apt-get -y install apt-utils build-essential automake libssl-dev libxml2-dev libxslt-dev ncurses-dev sudo libreadline-dev flex bison ragel memcached libmemcached-dev git curl libcurl4-openssl-dev imagemagick libmagickcore-dev libmagickwand-dev sendmail-bin sendmail postgresql-client libpq-dev nginx ssh coreutils ffmpeg mkvtoolnix emacs24-nox
RUN useradd -ms /bin/bash danbooru -u 1000
RUN mkdir /app
COPY . /app
RUN chown -R danbooru:danbooru /app
USER danbooru
ENV RAILS_ENV production
RUN echo 'export RAILS_ENV=production' >> ~/.profile
RUN echo 'gem: --no-document' > ~/.gemrc
RUN gem install bundler
WORKDIR /app
RUN bundle install
EXPOSE 3000
CMD bash
#CMD bundle exec rails server
