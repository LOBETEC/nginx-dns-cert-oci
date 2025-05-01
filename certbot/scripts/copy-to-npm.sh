#!/bin/sh

echo "[INFO] Iniciando copia de certificados definidos en .env..."

for i in $(seq 1 10); do
  CERT_NAME=$(eval echo \$CERT_NAME$i)
  NPM_DIR=$(eval echo \$NPM_DIR$i)

  if [ -z "$CERT_NAME" ] || [ -z "$NPM_DIR" ]; then
    continue
  fi

  SRC="/etc/letsencrypt/live/$CERT_NAME"
  DST="/shared_certs/$NPM_DIR"

  echo "[INFO] Copiando certificados de $CERT_NAME a $DST..."

  if [ -d "$SRC" ]; then
    mkdir -p "$DST"
    cp "$SRC/fullchain.pem" "$DST/"
    cp "$SRC/privkey.pem" "$DST/"
    cp "$SRC/chain.pem" "$DST/"
    chmod 600 "$DST"/*.pem
    echo "[OK] Certificados copiados a $DST"
  else
    echo "[WARN] No se encontró el directorio: $SRC"
  fi
done
