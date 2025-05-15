# NGINX Proxy Manager (NPM) + Certbot DNS OCI (Wildcard)

Automatización de certificados Let's Encrypt wildcard (`*.midominio.com`) usando Certbot con Oracle DNS (OCI), integrados con NGINX Proxy Manager (NPM). Completamente dockerizado, con emisión inicial automática y renovación diaria por `cron`.

---

## ✅ Características

- Contenedor WAF frontal (NGINX + ModSecurity) con reglas OWASP CRS para proteger NGINX Proxy Manager y servicios expuestos
- Certificados wildcard válidos para todos los subdominios (`*.midominio.com`)
- Emisión inicial automática al arrancar el contenedor `certbot`
- Copia automatizada de certificados a la carpeta `npm-XX` generada por NGINX Proxy Manager tras subir el certificado manualmente por primera vez
- Renovación diaria mediante `cron` dentro del contenedor
- Uso de variables de entorno vía `.env` para facilitar la portabilidad
- Separación modular con Docker Compose
- Script auxiliar para renovación manual (`renew-now.sh`)

---

## 📥 Clonar el repositorio

```bash
git clone https://github.com/LOBETEC/nginx-dns-cert-oci.git
cd nginx-dns-cert-oci
```

---

## 🌐 Apuntar el dominio a tu servidor NGINX

Asegúrate de que tu dominio (por ejemplo, `midominio.com`) y su wildcard (`*.midominio.com`) apuntan correctamente a la IP pública del servidor donde desplegarás NGINX Proxy Manager.

Esto lo puedes hacer creando registros DNS tipo A en tu proveedor de dominio:

- `@  →  IP_PUBLICA`
- `*  →  IP_PUBLICA`

> ⚠️ Esta configuración es **imprescindible** para que Let's Encrypt pueda validar el dominio vía DNS y emitir el certificado correctamente.

---

## 📂 Estructura del proyecto

```
docker/
├── docker-compose.yml
├── .env.example
├── certbot/
│   ├── Dockerfile
│   ├── scripts/
│   │   ├── entrypoint.sh
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

### 📜 Política necesaria en OCI

Crea la siguiente política en tu tenant de OCI para permitir que Certbot gestione los registros DNS:

```
Allow group CertbotGroup to manage dns in compartment nombre-compartimiento
```

Donde `CertbotGroup` es el grupo donde está el usuario asociado a las credenciales y `nombre-compartimiento` es el nombre del compartimento donde está gestionado el DNS.

Coloca tus credenciales en la ruta (estos datos se obtienen desde tu consola de Oracle Cloud Infrastructure al generar una API Key para tu usuario. Allí encontrarás el OCID del usuario, tenancy, fingerprint, región y podrás descargar el archivo `.pem`):

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
docker exec -it certbot /scripts/entrypoint.sh
```

Ver logs:

```bash
docker exec -it certbot cat /var/log/renew.log
```

---

## 🧪 Renovación manual (sin cron)

```bash
docker exec -it certbot /scripts/renew-now.sh
```

Este script:
- Renueva si procede
- Copia automáticamente los `.pem` a NPM

---

## 🔧 Renovación manual avanzada

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

## 🔧 Emisión manual de varios certificados

Puedes definir múltiples dominios y certificados en el archivo `.env`, usando sufijos:

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
🌐 https://lobetec.es

---

## 🏷️ Licencia

Uso interno autorizado para LOBETEC. Adaptable como ejemplo para proyectos DevOps y certificados con DNS-OCI.
---

## 🛡️ Contenedor WAF (ModSecurity) integrado

### 🔐 Protección adicional

Se ha añadido un contenedor WAF (NGINX + ModSecurity) como **proxy inverso frontal**, delante de NGINX Proxy Manager, que intercepta y filtra las peticiones entrantes para aumentar la seguridad.

### 📌 Características:

- Ejecuta NGINX con ModSecurity activado
- Usa el conjunto de reglas OWASP Core Rule Set (CRS)
- Registra y puede bloquear peticiones maliciosas (SQLi, XSS, etc.)
- Funciona como entrada principal en los puertos 80/443 y redirige a NPM internamente

### 🗂️ Estructura adicional

```
docker/
└── waf/
    ├── Dockerfile
    ├── modsecurity.conf
    ├── nginx.conf
    └── rules/
```

### ⚙️ Fragmento en `docker-compose.yml`:

```yaml
services:
  waf:
    build: ./waf
    ports:
      - "443:443"
    volumes:
      - ./waf/modsecurity.conf:/etc/modsecurity/modsecurity.conf
      - ./waf/nginx.conf:/etc/nginx/nginx.conf
      - ./waf/rules:/etc/modsecurity/rules
    depends_on:
      - npm
```

### 📊 Logs

Puedes inspeccionar eventos con:

```bash
docker exec -it waf tail -f /var/log/modsec_audit.log
```

### 🛠 Modo de operación

- Detección (solo registro): `SecRuleEngine DetectionOnly`
- Bloqueo: `SecRuleEngine On`

Edita esto en `modsecurity.conf` según necesidad.
