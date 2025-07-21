ARG RUBY_VERSION=3.3.6
ARG DOCKER_REGISTRY=docker.io
FROM $DOCKER_REGISTRY/ruby:$RUBY_VERSION-alpine
ENV RAILS_ENV=test

RUN apk --update add \
    build-base \
    git \
    postgresql-dev \
    postgresql17-client \
    mariadb-client \
    mariadb-dev \
    sqlite \
    sqlite-dev
RUN gem install bundler -v 2.5.13

COPY . /app
WORKDIR /app

RUN bundle install
RUN bundle exec appraisal install
