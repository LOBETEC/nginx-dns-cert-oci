#!/bin/sh

echo "[INFO] Procesando múltiples certificados..."

for i in $(seq 1 10); do
  DOMAIN=$(eval echo \$DOMAIN$i)
  EMAIL=$(eval echo \$EMAIL$i)
  CERT_NAME=$(eval echo \$CERT_NAME$i)
  NPM_DIR=$(eval echo \$NPM_DIR$i)

  if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ] || [ -z "$CERT_NAME" ] || [ -z "$NPM_DIR" ]; then
    continue
  fi

  echo "[INFO] Dominio $DOMAIN → certificado: $CERT_NAME → carpeta NPM: $NPM_DIR"

  CERT_PATH="/etc/letsencrypt/live/$CERT_NAME"

  if [ ! -f "$CERT_PATH/fullchain.pem" ]; then
    echo "[INFO] Certificado no existe. Generando..."
    certbot certonly \
      --authenticator dns-oci \
      --email "$EMAIL" \
      -d "$DOMAIN" -d "*.$DOMAIN" \
      --agree-tos \
      --non-interactive \
      --dns-oci-propagation-seconds 300 \
      --cert-name "$CERT_NAME"
  else
    echo "[INFO] Certificado $CERT_NAME ya existe. Renovando si es necesario..."
    certbot renew --cert-name "$CERT_NAME" --deploy-hook "echo 'Renovado $CERT_NAME'"
  fi

  # Copiar a NGINX Proxy Manager
  echo "[INFO] Copiando certificados a /shared_certs/$NPM_DIR..."
  mkdir -p "/shared_certs/$NPM_DIR"
  cp "$CERT_PATH/fullchain.pem" "/shared_certs/$NPM_DIR/"
  cp "$CERT_PATH/privkey.pem" "/shared_certs/$NPM_DIR/"
  cp "$CERT_PATH/chain.pem" "/shared_certs/$NPM_DIR/"
  chmod 600 "/shared_certs/$NPM_DIR/"*.pem
done

echo "[INFO] Iniciando cron para renovaciones automáticas..."
crontab /scripts/cronjob
crond -f
