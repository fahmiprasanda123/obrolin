# syntax=docker/dockerfile:1
#
# One image, three roles. The container command selects the role:
#   API:     bundle exec puma -C config/puma.rb
#   Cable:   bundle exec puma -p 3000 cable/config.ru
#   Sidekiq: bundle exec sidekiq -C config/sidekiq.yml
#
# Targets:
#   dev         - all gems, source bind-mounted by Docker Compose
#   production  - no dev/test gems, no compilers, runs as a non-root user

ARG RUBY_VERSION=3.3.5

# ---- base: runtime libraries shared by every stage ------------------------
FROM ruby:${RUBY_VERSION}-slim AS base
WORKDIR /app
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libpq5 libyaml-0-2 && \
    rm -rf /var/lib/apt/lists/*
ENV LANG=C.UTF-8 \
    BUNDLE_PATH=/usr/local/bundle \
    BOOTSNAP_CACHE_DIR=/tmp/bootsnap
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

# ---- build-base: compilers for native gems (pg, bcrypt, ...) --------------
FROM base AS build-base
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists/*

# ---- dev ------------------------------------------------------------------
FROM build-base AS dev
COPY Gemfile Gemfile.lock ./
RUN bundle install && chown -R rails:rails "$BUNDLE_PATH"
COPY --chown=rails:rails . .
USER 1000:1000
EXPOSE 3000
CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000", "-P", "/tmp/server.pid"]

# ---- build: production gems + bootsnap cache ------------------------------
FROM build-base AS build
ENV BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT="development:test"
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle "$BUNDLE_PATH"/ruby/*/cache "$BUNDLE_PATH"/ruby/*/bundler/gems/*/.git
COPY . .
ENV BOOTSNAP_CACHE_DIR=/app/tmp/cache
RUN bundle exec bootsnap precompile --gemfile app/ lib/

# ---- production: slim runtime image ---------------------------------------
FROM base AS production
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT="development:test" \
    BOOTSNAP_CACHE_DIR=/app/tmp/cache
COPY --from=build "$BUNDLE_PATH" "$BUNDLE_PATH"
COPY --from=build --chown=rails:rails /app /app
USER 1000:1000
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
