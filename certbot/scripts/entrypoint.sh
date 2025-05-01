#!/bin/sh

for i in 1 2; do
  DOMAIN=$(eval echo \$DOMAIN$i)
  EMAIL=$(eval echo \$EMAIL$i)
  CERT_NAME=$(eval echo \$CERT_NAME$i)

  if [ -z "$DOMAIN" ]; then
    continue
  fi

  echo "[INFO] Procesando certificado para: $DOMAIN"

  if [ ! -f "/etc/letsencrypt/live/$CERT_NAME/fullchain.pem" ]; then
    echo "[INFO] Generando certificado $CERT_NAME..."
    certbot certonly \
      --authenticator dns-oci \
      --email "$EMAIL" \
      -d "$DOMAIN" -d "*.$DOMAIN" \
      --agree-tos \
      --non-interactive \
      --dns-oci-propagation-seconds 300 \
      --cert-name "$CERT_NAME"
  else
    echo "[INFO] El certificado $CERT_NAME ya existe. No se regenera."
  fi
done

echo "[INFO] Iniciando cron para renovación automática..."
crontab /scripts/cronjob
crond -f
