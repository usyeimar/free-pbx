<p align="center">
  <img src="https://www.freepbx.org/wp-content/uploads/2024/02/FreePBX-logo.png" alt="FreePBX" width="280"/>
</p>

<h1 align="center">FreePBX 17</h1>

<p align="center">
  <strong>Central telefónica IP empresarial, lista en contenedores.</strong><br/>
  FreePBX 17 + Asterisk compilado desde source, orquestado con Docker Compose y endurecido con Fail2ban.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Debian-Bookworm-A81D33?style=flat-square&amp;logo=debian" alt="Debian 12"/>
  <img src="https://img.shields.io/badge/Asterisk-21.10-1E40AF?style=flat-square&amp;logo=asterisk" alt="Asterisk 21"/>
  <img src="https://img.shields.io/badge/PHP-8.2-777BB4?style=flat-square&amp;logo=php" alt="PHP 8.2"/>
  <img src="https://img.shields.io/badge/MariaDB-10.11-003545?style=flat-square&amp;logo=mariadb" alt="MariaDB 10.11"/>
  <img src="https://img.shields.io/badge/Fail2ban-Incluido-DC382D?style=flat-square&amp;logo=shield" alt="Fail2ban"/>
</p>

---

## ¿Qué es esto?

**FreePBX** es la interfaz web de código abierto más usada para administrar **Asterisk**, el motor de telefonía que mueve a millones de centrales (PBX) en el mundo. Te da, desde el navegador, todo lo que necesita una empresa para tener su propio sistema de teléfonos: extensiones, IVR (menús "marque 1 para ventas"), colas y grupos de timbrado, buzón de voz a email, grabación de llamadas, troncales SIP hacia tu proveedor y reportes de CDR.

El problema es que instalarlo "a mano" implica compilar Asterisk, configurar Apache + PHP + MariaDB y ajustar decenas de piezas — un proceso de horas, frágil y difícil de reproducir.

**Este repositorio empaqueta todo eso en un stack de Docker Compose reproducible:**

- 🐳 **Una imagen construida desde `source/Dockerfile`** — Asterisk compilado desde el código oficial (control total del build, sin depender de imágenes opacas de terceros).
- 🗄️ **MariaDB** como base de datos, con `init.sql` y `my.cnf` ya cableados.
- 🛡️ **Fail2ban** en un contenedor aparte que banea automáticamente los ataques de fuerza bruta contra el SIP — el dolor de cabeza nº1 de cualquier PBX expuesta a internet.
- ⚙️ **Scripts y `.env`** que resuelven los detalles espinosos (rango de puertos RTP vía iptables, TLS con Let's Encrypt, relay SMTP para notificaciones).

En resumen: pasas de cero a una central telefónica IP empresarial funcional con un par de comandos, en lugar de una tarde entera de instalación manual.

---

## Stack

| Componente | Versión | Rol |
|:---|:---|:---|
| Debian | Bookworm (12) | Sistema operativo base |
| FreePBX | 17.0.21 | Gestión de PBX |
| Asterisk | 21.10.2 | Motor de telefonía |
| PHP | 8.2 | Backend web |
| Apache | 2.4 | Servidor web |
| MariaDB | 10.11 | Base de datos |
| Fail2ban | latest | Protección contra brute-force |
| Node.js | 18 | UCP / WebRTC |

---

## Inicio rápido

```bash
# 1. Configurar variables de entorno
cp .env.example .env
nano .env

# 2. Construir imagen y levantar
sudo ./scripts/start.sh

# 3. Instalar FreePBX (solo la primera vez)
sudo ./scripts/install.sh

# 4. Acceder → http://<tu-ip>
```

> La primera construcción tarda ~15-20 min (compila Asterisk desde source).

---

## Scripts

| Comando | Descripción |
|:---|:---|
| `sudo ./scripts/start.sh` | Build + compose up + iptables RTP |
| `sudo ./scripts/start.sh 10000-20000` | Rango RTP personalizado |
| `sudo ./scripts/stop.sh` | Detiene los contenedores |
| `sudo ./scripts/install.sh` | Instala FreePBX en el contenedor |
| `./scripts/logs.sh` | Logs de FreePBX en vivo |
| `./scripts/logs.sh db` | Logs de MariaDB |
| `sudo ./scripts/tls.sh dominio.com email` | Certbot Let's Encrypt |
| `sudo ./scripts/clean.sh` | Elimina todo (pide confirmación) |

---

## Variables de entorno

| Variable | Descripción | Ejemplo |
|:---|:---|:---|
| `MYSQL_ROOT_PASSWORD` | Password root MariaDB | `s3cur3R00t!` |
| `MYSQL_USER` | Usuario de base de datos | `freepbxuser` |
| `MYSQL_PASSWORD` | Password del usuario DB | `myP@ss2025` |
| `SMTP_RELAY` | Servidor SMTP relay | `[smtp.gmail.com]:587` |
| `SMTP_USER` | Email para notificaciones | `pbx@empresa.com` |
| `SMTP_PASSWORD` | App password del email | `xxxx xxxx xxxx` |
| `TZ` | Zona horaria | `America/Mexico_City` |

---

## Puertos

| Puerto | Protocolo | Servicio |
|:---|:---|:---|
| 80 | TCP | Panel web HTTP |
| 443 | TCP | Panel web HTTPS |
| 5060 | UDP | PJSIP (señalización) |
| 16384–32767 | UDP | RTP (audio) — via iptables |

> Los puertos RTP se manejan con iptables en el host porque Docker tiene un [bug conocido](https://github.com/moby/moby/issues/11185) al exponer rangos grandes de puertos.

---

## Volúmenes

| Volumen | Contenido |
|:---|:---|
| `mysql_data` | Base de datos MariaDB |
| `freepbx_var` | Datos de Asterisk, logs, grabaciones, voicemail |
| `freepbx_etc` | Configuración de Asterisk y FreePBX |

---

## Estructura del proyecto

```
.
├── compose.yml                 Orquestación de servicios
├── .env.example                Plantilla de variables
├── config/
│   ├── fail2ban/
│   │   ├── jail.local          Reglas de baneo
│   │   └── filter.d/
│   │       └── asterisk.conf   Filtro de logs Asterisk
│   └── mariadb/
│       ├── my.cnf              Configuración MariaDB
│       └── init.sql            Creación de bases de datos
├── scripts/
│   ├── start.sh                Build + levantar + iptables RTP
│   ├── stop.sh                 Detener
│   ├── install.sh              Instalar FreePBX
│   ├── clean.sh                Limpieza total
│   ├── logs.sh                 Ver logs
│   └── tls.sh                  Configurar HTTPS
└── source/
    ├── Dockerfile              Imagen FreePBX (Asterisk compilado)
    ├── entrypoint.sh           Arranque de servicios
    ├── logrotate/asterisk      Rotación de logs
    ├── odbc/                   Conectores ODBC para CDR
    └── postfix/main.cf         Configuración de email
```

---

## Comandos útiles

```bash
# Shell dentro del contenedor
docker compose exec freepbx bash

# CLI de Asterisk
docker compose exec freepbx asterisk -rvvv

# Ver endpoints SIP registrados
docker compose exec freepbx asterisk -rx "pjsip show endpoints"

# Consola MariaDB
docker compose exec db mysql -u root -p

# Backup FreePBX
docker compose exec freepbx fwconsole backup --backup=default

# Reconstruir imagen (después de cambios en source/)
docker compose build freepbx
```

---

## Seguridad (Fail2ban)

- Banea IPs tras **2 intentos fallidos** de registro SIP en **30 segundos**
- Duración del ban: **1 semana**
- Actúa sobre la cadena `DOCKER-USER` de iptables
- IPs locales (RFC1918) están en whitelist

---

## Notas

- La imagen se compila localmente desde `source/Dockerfile` — control total del build.
- Fail2ban corre en un contenedor separado con `network_mode: host` para manipular iptables directamente.
- Todos los scripts hacen `cd` al root del proyecto automáticamente — ejecútalos desde cualquier directorio.
- Requisitos del host: Docker Engine 24+, Docker Compose v2, Linux con `iptables`.

---

## Créditos

Basado en [escomputers/freepbx-docker](https://github.com/escomputers/freepbx-docker) (Apache 2.0).
FreePBX es software libre bajo GPL.
