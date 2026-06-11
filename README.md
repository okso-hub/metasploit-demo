# Metasploit Demo-Sammlung

Drei Live-Demos fuer eine Praesentation zu Penetration Testing mit Metasploit. Jedes Szenario laeuft komplett in Docker-Containern — isoliert, reproduzierbar, sicher.

## Szenarien

| # | Szenario | Angriffstechnik | Status |
|---|----------|-----------------|--------|
| 1 | [Samba-Exploit mit Datendiebstahl](szenario-1-samba-exploit/) | SambaCry (CVE-2017-7494) → Root-Shell → Daten exfiltrieren | fertig |
| 2 | [Trojaner einspielen (Backdoor)](szenario-2-trojaner-backdoor/) | msfvenom-Trojaner → Meterpreter-Session → Cron-Persistenz | fertig |
| 3 | SSH Brute-Force | Hydra/Metasploit Passwort-Angriff auf SSH | geplant |

## Schnellstart

```sh
cd szenario-1-samba-exploit
docker compose up -d --build
docker attach msf-attacker
```

Detaillierte Anleitungen in der jeweiligen README im Szenario-Ordner.

## Voraussetzungen

- Docker + Docker Compose
- ca. 2-3 GB freier Speicher
- Internetverbindung beim ersten Start (Image-Download)
