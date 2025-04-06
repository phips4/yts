# Use the official Elixir 1.18 image
FROM elixir:1.18

# Install build tools and Node.js
RUN apt-get update && apt-get install -y \
    inotify-tools \
    build-essential \
    git \
    curl \
    wget \
    unzip \
    nodejs \
    npm \
    && apt-get clean

# Install Hex, Rebar, and Phoenix 1.8.0-rc.0
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix archive.install hex phx_new 1.8.0-rc.0 --force

# Install LiveView dependencies
RUN npm install -g esbuild

WORKDIR /workspace
