#!/bin/sh

export PYTHONWARNINGS="ignore::DeprecationWarning"

echo "[INFO] Ejecutando renovación manual de certificados..."

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
    echo "[INFO] Certificado no existe. Intentando generar..."
    certbot certonly \
      --authenticator dns-oci \
      --email "$EMAIL" \
      -d "$DOMAIN" -d "*.$DOMAIN" \
      --agree-tos \
      --non-interactive \
      --dns-oci-propagation-seconds 300 \
      --cert-name "$CERT_NAME"
  else
    echo "[INFO] Certificado $CERT_NAME ya existe. Renovando si aplica..."
    certbot renew --cert-name "$CERT_NAME"
  fi

  if [ -f "$CERT_PATH/fullchain.pem" ] && [ -f "$CERT_PATH/privkey.pem" ]; then
    DST="/shared_certs/$NPM_DIR"
    echo "[INFO] Copiando certificados a $DST..."
    mkdir -p "$DST"
    cp "$CERT_PATH/fullchain.pem" "$DST/"
    cp "$CERT_PATH/privkey.pem" "$DST/"
    cp "$CERT_PATH/chain.pem" "$DST/"
    chmod 600 "$DST"/*.pem
    echo "[OK] Copiados certificados de $CERT_NAME → $NPM_DIR"
  else
    echo "[WARN] No se encontraron archivos válidos para $CERT_NAME"
  fi
done

echo "[INFO] Renovación manual finalizada."

