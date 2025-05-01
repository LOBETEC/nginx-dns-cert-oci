#!/bin/sh

echo "[INFO] Ejecutando renovación de certificados"
certbot renew --quiet --deploy-hook "/scripts/copy-to-npm.sh"
