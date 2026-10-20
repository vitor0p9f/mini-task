# syntax=docker/dockerfile:1

# ---- Build stage -------------------------------------------------------------
FROM elixir:1.18-slim AS build

ENV MIX_ENV=prod

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      git \
      ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

# Fetch dependencies first so this layer is cached while source code changes.
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

COPY config config
COPY priv priv
COPY assets assets
COPY lib lib

# Compiles the app, builds/digests assets and assembles the OTP release.
RUN mix deps.compile \
    && mix assets.setup \
    && mix assets.deploy \
    && mix release

# ---- Runtime stage -----------------------------------------------------------
FROM debian:bookworm-slim AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      libncurses6 \
      libstdc++6 \
      openssl \
      tzdata \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=prod \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    HOME=/home/app \
    RELEASE_TMP=/app/tmp

COPY --from=build /app/_build/prod/rel/mini_task ./
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN useradd --uid 1000 --create-home --shell /bin/bash app \
    && mkdir -p /app/tmp \
    && chmod +x /usr/local/bin/docker-entrypoint.sh \
    && chown -R app:app /app

USER app

EXPOSE 4000

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/app/bin/mini_task", "start"]
