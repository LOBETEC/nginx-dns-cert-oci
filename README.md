# NGINX Proxy Manager (NPM) + Certbot DNS OCI (Wildcard)


Automatización de certificados Let's Encrypt wildcard (`*.midominio.com`) usando Certbot con Oracle DNS (OCI), integrados con NGINX Proxy Manager (NPM). Completamente dockerizado, con emisión inicial automática y renovación diaria por `cron`.

---

## ✅ Características

- Certificados wildcard válidos para todos los subdominios (`*.midominio.com`)
- Emisión inicial automática al arrancar el contenedor `certbot`
- Copia automatizada de certificados a la carpeta `npm-XX` generada por NGINX Proxy Manager tras subir el certificado manualmente por primera vez
- Renovación diaria mediante `cron` dentro del contenedor
- Uso de variables de entorno vía `.env` para facilitar la portabilidad
- Separación modular con Docker Compose
- Script auxiliar para renovación manual (`renew-now.sh`)

---

## 📂 Estructura del proyecto

```
docker/
├── docker-compose.yml
├── .env.example
├── certbot/
│   ├── Dockerfile
│   ├── scripts/
│   │   ├── copy-to-npm.sh
│   │   ├── renew-and-copy.sh
│   │   └── cronjob
│   ├── oci_credentials/   ⚠️ NO subir al repo
│   └── shared_certs/
├── npm/
│   └── (volúmenes persistentes de NPM)
```

---

## ⚠️ Seguridad

### No subas nunca:

- `certbot/oci_credentials/config`
- `certbot/oci_credentials/oci_api_key.pem`
- Archivos `.pem` ni tu archivo `.env` real

Ya están excluidos en `.gitignore`, pero revísalo antes de hacer `git add`.

---

## 🔐 Configuración de credenciales OCI

Coloca tus credenciales en la ruta:

```
certbot/oci_credentials/
├── config
├── oci_api_key.pem
```

Asegúrate de que el archivo `config` contiene:

```ini
[DEFAULT]
user=ocid1.user.oc1..xxxxx
fingerprint=xx:xx:xx:...
key_file=/root/.oci/oci_api_key.pem
tenancy=ocid1.tenancy.oc1..xxxxx
region=eu-frankfurt-1
```

Estas credenciales se montan en `/root/.oci` dentro del contenedor `certbot`.

---

## 🗂️ ¿Cómo saber qué carpeta usar (`npm-XX`) en NGINX Proxy Manager?

Cuando subes por primera vez un certificado personalizado desde la interfaz web de NGINX Proxy Manager (SSL → Custom → Add Certificate), NPM crea internamente una carpeta como:

```
/data/custom_ssl/npm-1/
```

1. Sube una vez el `.pem` desde la interfaz de NPM (SSL > Custom)
2. Observa en `/data/custom_ssl/` la carpeta creada
3. Usa ese número (`npm-1`, `npm-2`, etc.) en tu `.env`

---

## 🔧 Ejemplo `.env`

```dotenv
DOMAIN1=midominio1.com
EMAIL1=admin@midominio1.com
CERT_NAME1=midominio1.com
NPM_DIR1=npm-1

DOMAIN2=midominio2.com
EMAIL2=admin@midominio2.com
CERT_NAME2=midominio2.com
NPM_DIR2=npm-2
```

Puedes seguir añadiendo más pares secuenciales (`DOMAIN3`, etc.)
---

## 🚀 Uso

### 1. Clona el repositorio y copia `.env`

```bash
cp .env.example .env
```

Edita con tus valores reales de dominio, email, etc.

---

### 2. Construye y lanza los servicios

```bash
docker compose build --no-cache
docker compose up -d
```

Si el certificado no existe aún, se generará automáticamente. Luego, `cron` se encargará de renovarlo cada día a las 03:00.

---

## 🔁 Renovación automática (cron)

El contenedor `certbot` ejecuta:

```bash
certbot renew --deploy-hook "/scripts/copy-to-npm.sh"
```

Ver logs:

```bash
docker exec -it certbot cat /var/log/renew.log
```

---

## 🔧 Renovación manual (si lo necesitas)

```bash
docker exec -it certbot certbot renew --dry-run
```

O para forzar la emisión inicial:

```bash
docker exec -it certbot certbot certonly \
  --authenticator dns-oci \
  --email $EMAIL \
  -d $DOMAIN \
  -d *.$DOMAIN \
  --agree-tos \
  --non-interactive \
  --dns-oci-propagation-seconds 300 \
  --cert-name $CERT_NAME
```

---


## 🔧 Emisión manual de varios certificados (si lo necesitas)

Puedes definir múltiples dominios y certificados en el archivo `.env`, usando sufijos:

```dotenv
DOMAIN1=midominio1.com
EMAIL1=admin@midominio1.com
CERT_NAME1=midominio1.com

DOMAIN2=midominio2.com
EMAIL2=admin@midominio2.com
CERT_NAME2=midominio2.com
```

El contenedor `certbot` procesará cada grupo de variables (`DOMAINi`, `EMAILi`, `CERT_NAMEi`) en orden, y emitirá un certificado wildcard para cada uno si no existe todavía:

```bash
for i in 1 2; do
  DOMAIN=$(eval echo \$DOMAIN$i)
  EMAIL=$(eval echo \$EMAIL$i)
  CERT_NAME=$(eval echo \$CERT_NAME$i)

  if [ -z "$DOMAIN" ]; then
    continue
  fi

  if [ ! -f "/etc/letsencrypt/live/$CERT_NAME/fullchain.pem" ]; then
    certbot certonly \
      --authenticator dns-oci \
      --email "$EMAIL" \
      -d "$DOMAIN" -d "*.$DOMAIN" \
      --agree-tos \
      --non-interactive \
      --dns-oci-propagation-seconds 300 \
      --cert-name "$CERT_NAME"
  fi
done
```

```
## 🔁 Renovación automática (cron)

El contenedor `certbot` ejecuta cada día a las 03:00:

```bash
/scripts/entrypoint.sh
```

`crond` se mantiene en primer plano con `crond -f`.

---

## 🧪 Renovación manual (sin cron)

```bash
docker exec -it certbot /scripts/renew-now.sh
```

Este script:
- Renueva si procede
- Copia automáticamente los `.pem` a NPM

---

## 🛠 Resetear todo

```bash
docker compose down
rm -rf ./npm/data
rm -rf ./certbot/etc/letsencrypt/*
rm -rf ./certbot/shared_certs/*
docker compose up -d
```

---

## 👤 Autor

**LOBETEC** – Expertos en Oracle APEX  
📍 Málaga, España  
🌐 [https://lobetec.es](https://lobetec.es)

---

## 🏷️ Licencia

Uso interno autorizado para LOBETEC. Adaptable como ejemplo para proyectos DevOps y certificados con DNS-OCI.


