<p align="center">
  <img src="assets/freepbx-logo.png" alt="FreePBX" width="200"/>
</p>

<h1 align="center">FreePBX 17</h1>

<p align="center">
  <strong>Enterprise IP PBX, ready to run in containers.</strong><br/>
  FreePBX 17 + Asterisk built from source, orchestrated with Docker Compose and hardened with Fail2ban.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Debian-Bookworm-A81D33?style=flat-square&amp;logo=debian" alt="Debian 12"/>
  <img src="https://img.shields.io/badge/Asterisk-21.10-1E40AF?style=flat-square&amp;logo=asterisk" alt="Asterisk 21"/>
  <img src="https://img.shields.io/badge/PHP-8.2-777BB4?style=flat-square&amp;logo=php" alt="PHP 8.2"/>
  <img src="https://img.shields.io/badge/MariaDB-10.11-003545?style=flat-square&amp;logo=mariadb" alt="MariaDB 10.11"/>
  <img src="https://img.shields.io/badge/Fail2ban-included-DC382D?style=flat-square&amp;logo=shield" alt="Fail2ban"/>
</p>

---

## What is this?

**FreePBX** is the most widely used open-source web interface for managing **Asterisk**, the telephony engine that powers millions of phone systems (PBXs) worldwide. From the browser it gives a company everything it needs to run its own phone system: extensions, IVRs ("press 1 for sales" menus), call queues and ring groups, voicemail-to-email, call recording, SIP trunks to your provider, and CDR reports.

The catch is that installing it "by hand" means compiling Asterisk, configuring Apache + PHP + MariaDB, and tuning dozens of moving parts — a multi-hour, fragile, hard-to-reproduce process.

**This repository packages all of that into a reproducible Docker Compose stack:**

- 🐳 **An image built from `source/Dockerfile`** — Asterisk compiled from official source (full control over the build, no reliance on opaque third-party images).
- 🗄️ **MariaDB** as the database, with `init.sql` and `my.cnf` already wired up.
- 🛡️ **Fail2ban** in a separate container that automatically bans SIP brute-force attacks — the #1 headache of any internet-facing PBX.
- ⚙️ **Scripts and `.env`** that handle the thorny details (RTP port range via iptables, TLS with Let's Encrypt, SMTP relay for notifications).

In short: you go from zero to a working enterprise IP PBX with a couple of commands, instead of a full afternoon of manual setup.

---

## Stack

| Component | Version | Role |
|:---|:---|:---|
| Debian | Bookworm (12) | Base operating system |
| FreePBX | 17.0.21 | PBX management |
| Asterisk | 21.10.2 | Telephony engine |
| PHP | 8.2 | Web backend |
| Apache | 2.4 | Web server |
| MariaDB | 10.11 | Database |
| Fail2ban | latest | Brute-force protection |
| Node.js | 18 | UCP / WebRTC |

---

## Quickstart

```bash
# 1. Set up environment variables
cp .env.example .env
nano .env

# 2. Build the image, bring it up, and install FreePBX
#    (the script installs FreePBX automatically on first run)
sudo ./scripts/start.sh

# 3. Open → http://<your-ip>
```

> The first build takes ~15-20 min (it compiles Asterisk from source).

---

## Scripts

| Command | Description |
|:---|:---|
| `sudo ./scripts/start.sh` | Build + compose up + iptables RTP + install FreePBX |
| `sudo ./scripts/start.sh 10000-20000` | Custom RTP range |
| `sudo ./scripts/stop.sh` | Stop the containers |
| `./scripts/logs.sh` | Live FreePBX logs |
| `./scripts/logs.sh db` | MariaDB logs |
| `sudo ./scripts/tls.sh domain.com email` | Let's Encrypt via Certbot |
| `sudo ./scripts/clean.sh` | Remove everything (asks for confirmation) |

---

## Environment variables

| Variable | Description | Example |
|:---|:---|:---|
| `MYSQL_ROOT_PASSWORD` | MariaDB root password | `s3cur3R00t!` |
| `MYSQL_USER` | Database user | `freepbxuser` |
| `MYSQL_PASSWORD` | Database user password | `myP@ss2025` |
| `SMTP_RELAY` | SMTP relay server | `[smtp.gmail.com]:587` |
| `SMTP_USER` | Email used for notifications | `pbx@company.com` |
| `SMTP_PASSWORD` | Email app password | `xxxx xxxx xxxx` |
| `TZ` | Time zone | `America/Mexico_City` |

---

## Ports

| Port | Protocol | Service |
|:---|:---|:---|
| 80 | TCP | Web panel (HTTP) |
| 443 | TCP | Web panel (HTTPS) |
| 5060 | UDP | PJSIP (signaling) |
| 16384–32767 | UDP | RTP (audio) — via iptables |

> RTP ports are handled with iptables on the host because Docker has a [known bug](https://github.com/moby/moby/issues/11185) when publishing large port ranges.

---

## Volumes

| Volume | Contents |
|:---|:---|
| `mysql_data` | MariaDB database |
| `freepbx_var` | Asterisk data, logs, recordings, voicemail |
| `freepbx_etc` | Asterisk and FreePBX configuration |

---

## Project structure

```
.
├── compose.yml                 Service orchestration
├── .env.example                Variables template
├── config/
│   ├── fail2ban/
│   │   ├── jail.local          Ban rules
│   │   └── filter.d/
│   │       └── asterisk.conf   Asterisk log filter
│   └── mariadb/
│       ├── my.cnf              MariaDB configuration
│       └── init.sql            Database creation
├── scripts/
│   ├── start.sh                Build + up + iptables RTP + install FreePBX
│   ├── stop.sh                 Stop
│   ├── clean.sh                Full cleanup
│   ├── logs.sh                 View logs
│   └── tls.sh                  Configure HTTPS
└── source/
    ├── Dockerfile              FreePBX image (Asterisk compiled)
    ├── entrypoint.sh           Service startup
    ├── logrotate/asterisk      Log rotation
    ├── odbc/                   ODBC connectors for CDR
    └── postfix/main.cf         Email configuration
```

---

## Useful commands

```bash
# Shell inside the container
docker compose exec freepbx bash

# Asterisk CLI
docker compose exec freepbx asterisk -rvvv

# Show registered SIP endpoints
docker compose exec freepbx asterisk -rx "pjsip show endpoints"

# MariaDB console
docker compose exec db mysql -u root -p

# FreePBX backup
docker compose exec freepbx fwconsole backup --backup=default

# Rebuild the image (after changes in source/)
docker compose build freepbx
```

---

## Security (Fail2ban)

- Bans IPs after **2 failed** SIP registration attempts within **30 seconds**
- Ban duration: **1 week**
- Acts on the iptables `DOCKER-USER` chain
- Local IPs (RFC1918) are whitelisted

---

## Notes

- The image is built locally from `source/Dockerfile` — full control over the build.
- Fail2ban runs in a separate container with `network_mode: host` so it can manipulate iptables directly.
- All scripts `cd` to the project root automatically — run them from any directory.
- Host requirements: Docker Engine 24+, Docker Compose v2, Linux with `iptables`.

---

## Credits

Based on [escomputers/freepbx-docker](https://github.com/escomputers/freepbx-docker) (Apache 2.0).
FreePBX is free software under the GPL.
