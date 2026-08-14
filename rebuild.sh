#!/usr/bin/env bash
# Reconstruit l'ISO de zero. A lancer en root :
#
#   sudo /home/jinshi/dev/perso/caelestia-wany-iso/rebuild.sh
#
# Vide work/ au prealable : mkarchiso ne repart pas proprement d'un repertoire
# de travail laisse par une construction precedente. Journalise dans
# /tmp/iso-build.log pour pouvoir diagnostiquer un echec apres coup.

set -uo pipefail

ROOT=/home/jinshi/dev/perso/caelestia-wany-iso
LOG=/tmp/iso-build.log

[[ $EUID -eq 0 ]] || { echo "a lancer avec sudo" >&2; exit 1; }

echo ":: Nettoyage du repertoire de travail"
rm -rf "$ROOT/work"

echo ":: Construction (20-40 min) — journal : $LOG"
mkarchiso -v -w "$ROOT/work" -o "$ROOT/out" "$ROOT/profile" 2>&1 | tee "$LOG"
rc=${PIPESTATUS[0]}

echo
if [[ $rc -eq 0 ]]; then
    echo ":: Termine"
    ls -lh "$ROOT"/out/*.iso
else
    echo ":: ECHEC (code $rc) — les dernieres lignes sont dans $LOG"
fi
exit $rc
