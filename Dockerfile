ARG RUBY_VERSION=3.4.5
ARG DOCKER_REGISTRY=docker.io
FROM $DOCKER_REGISTRY/ruby:$RUBY_VERSION-alpine
ENV RAILS_ENV=test

RUN apk --update add \
    gcompat \
    build-base \
    git \
    postgresql-dev \
    postgresql17-client \
    mariadb-client \
    mariadb-dev \
    sqlite \
    sqlite-dev

COPY . /app
WORKDIR /app

RUN gem install bundler -v $(cat Gemfile.lock | grep "BUNDLED WITH" -A1 | tail -n1)
RUN bundle install
RUN bundle exec appraisal install
