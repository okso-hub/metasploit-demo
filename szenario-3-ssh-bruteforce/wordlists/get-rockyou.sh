#!/bin/bash
# Laedt die echte rockyou.txt (~133 MB, 14,3 Mio. Passwoerter) in dieses Verzeichnis.
# rockyou.txt wird NICHT mit eingecheckt (siehe .gitignore) — daher dieses Skript.
set -e
cd "$(dirname "$0")"

if [ -f rockyou.txt ]; then
  echo "rockyou.txt ist bereits vorhanden ($(wc -l < rockyou.txt) Zeilen)."
  exit 0
fi

# Auf Kali liegt rockyou meist schon lokal vor:
if [ -f /usr/share/wordlists/rockyou.txt ]; then
  echo "Kopiere von /usr/share/wordlists/rockyou.txt ..."
  cp /usr/share/wordlists/rockyou.txt rockyou.txt
elif [ -f /usr/share/wordlists/rockyou.txt.gz ]; then
  echo "Entpacke /usr/share/wordlists/rockyou.txt.gz ..."
  gunzip -c /usr/share/wordlists/rockyou.txt.gz > rockyou.txt
else
  echo "Lade rockyou.txt herunter ..."
  curl -L -o rockyou.txt \
    https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt
fi

echo "Fertig: $(wc -l < rockyou.txt) Passwoerter in $(pwd)/rockyou.txt"
