ARG RUBY_VERSION=3.2.3
ARG DOCKER_REGISTRY=docker.io
FROM $DOCKER_REGISTRY/ruby:$RUBY_VERSION-alpine
ENV RAILS_VERSION="8.0.0"
ENV RAILS_ENV=test

RUN apk --update add \
    build-base \
    git \
    postgresql-dev \
    postgresql17-client \
    mariadb-client \
    mariadb-dev
RUN gem install bundler -v 2.5.13

COPY . /app
WORKDIR /app

RUN bundle install
RUN bundle exec appraisal install

