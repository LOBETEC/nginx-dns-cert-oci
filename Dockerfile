FROM python:3.10-alpine

RUN apk add --no-cache \
      bash \
      gcc \
      musl-dev \
      libffi-dev \
      openssl-dev \
      cargo \
      curl \
      coreutils \
    && pip install --upgrade pip \
    && pip install certbot==2.6.0 certbot-dns-oci
