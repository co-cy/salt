# syntax=docker/dockerfile:1.6
#
# Build environment for cy/* Salt deb packages.
# Built per-codename: salt-cy-build-deb:bullseye / :bookworm
#
ARG DEBIAN_CODENAME=bookworm
FROM debian:${DEBIAN_CODENAME}-slim

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_INPUT=1

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        bash-completion \
        build-essential \
        ca-certificates \
        curl \
        debhelper \
        devscripts \
        dh-python \
        git \
        patchelf \
        python3 \
        python3-dev \
        python3-pip \
        python3-venv \
 && rm -rf /var/lib/apt/lists/*

# Rust toolchain for relenv (compiles native bits while building onedir).
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --profile minimal --default-toolchain stable
ENV PATH=/root/.cargo/bin:$PATH

# Isolated Python venv with the build CLI.
RUN python3 -m venv /opt/build-venv \
 && /opt/build-venv/bin/pip install --upgrade pip wheel
ENV PATH=/opt/build-venv/bin:$PATH

RUN pip install \
        ptscripts \
        "relenv==0.22.4" \
        ppbt

WORKDIR /salt

COPY build-deb-inside.sh /usr/local/bin/build-deb-inside.sh
RUN chmod +x /usr/local/bin/build-deb-inside.sh

CMD ["/usr/local/bin/build-deb-inside.sh"]
