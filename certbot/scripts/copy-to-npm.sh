#!/bin/bash

CERT_DOMAIN=lobetec.app
SRC="/etc/letsencrypt/live/$CERT_DOMAIN"
DST="/shared_certs/npm-22"

echo "[INFO] Copiando certificados desde $SRC a $DST..."

mkdir -p "$DST"

cp "$SRC/fullchain.pem" "$DST/"
cp "$SRC/privkey.pem" "$DST/"
cp "$SRC/chain.pem" "$DST/"

chmod 600 "$DST"/*.pem

echo "[INFO] Certificados actualizados correctamente en $DST"
