FROM ubuntu:22.04

# Cron fuer die spaetere Backdoor-Persistenz; sonst ein ganz normaler Desktop-User.
RUN apt-get update \
 && apt-get install -y --no-install-recommends cron \
 && rm -rf /var/lib/apt/lists/*

# Normaler Mitarbeiter-Account (KEIN root) — realistisch fuer eine Workstation.
RUN useradd -m -s /bin/bash mitarbeiter \
 && mkdir -p /home/mitarbeiter/Downloads \
 && chown -R mitarbeiter:mitarbeiter /home/mitarbeiter

# Cron-Laufzeitverzeichnis sicherstellen
RUN mkdir -p /var/run /var/spool/cron/crontabs
