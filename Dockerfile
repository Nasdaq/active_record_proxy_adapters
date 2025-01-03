ARG RUBY_VERSION=3.2.3
ARG DOCKER_REGISTRY=docker.io
FROM $DOCKER_REGISTRY/ruby:$RUBY_VERSION-alpine
ARG RAILS_VERSION="~> 6.1.0"
ENV RAILS_VERSION=$RAILS_VERSION

RUN apk --update add \
    build-base \
    git \
    postgresql-dev \
    postgresql17-client
RUN gem install bundler -v 2.5.13

COPY . /app
WORKDIR /app

RUN bundle install

