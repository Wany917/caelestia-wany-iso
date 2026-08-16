#!/usr/bin/env fish
# Prepare et publie une release GitHub avec l'ISO.
#
# GitHub refuse tout fichier de plus de 2 Gio dans une release, or l'image en fait
# pres de 3. Elle est donc decoupee en morceaux, avec les empreintes SHA256 de
# chaque morceau ET de l'image reconstituee, pour que le telechargeur puisse
# verifier les deux etapes.
#
#   scripts/make-release.fish [--tag vX.Y] [--dry-run]

argparse -n 'make-release.fish' 'h/help' 'tag=' 'dry-run' -- $argv
or exit 1

set -g root (realpath (dirname (status filename))/..)
set -g rel "$root/release"
set -g part_size 1900M

if set -q _flag_help
    echo 'usage: scripts/make-release.fish [--tag vX.Y] [--dry-run]'
    echo
    echo '  --tag      nom du tag (defaut : derive de la date de l ISO)'
    echo '  --dry-run  prepare les fichiers sans rien publier'
    exit
end

function _out -a text
    set_color cyan; echo "[release] $text"; set_color normal
end
function _die -a text
    set_color -o red; echo "[release] $text" >&2; set_color normal; exit 1
end

set -l iso (find "$root/out" -maxdepth 1 -name '*.iso' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
test -n "$iso"; or _die 'aucune ISO dans out/ — lance d abord la construction'

set -l base (basename "$iso")
set -l tag (string replace -r '^caelestia-wany-([0-9.]+)-x86_64\.iso$' 'v$1' -- $base)
set -q _flag_tag; and set tag $_flag_tag

_out "ISO : $base ("(du -h "$iso" | cut -f1)")"
_out "tag : $tag"

# --- decoupe ---
rm -rf "$rel"; mkdir -p "$rel"
_out "decoupe en morceaux de $part_size"
split -b $part_size -d --additional-suffix=.part "$iso" "$rel/$base."
ls "$rel" | sed 's/^/    /'

# --- empreintes ---
# Celle de l'ISO entiere sert a verifier le fichier RECONSTITUE, celles des
# morceaux a reperer un telechargement corrompu avant meme de recoller.
_out 'calcul des empreintes'
set -l iso_sum (sha256sum "$iso" | cut -d' ' -f1)
begin
    echo "# ISO reconstituee"
    echo "$iso_sum  $base"
    echo
    echo "# Morceaux"
    for f in "$rel"/*.part
        echo (sha256sum "$f" | cut -d' ' -f1)"  "(basename "$f")
    end
end > "$rel/SHA256SUMS"
cat "$rel/SHA256SUMS" | sed 's/^/    /'

# --- verification : le recollage redonne bien l ISO ---
# On ne publie pas des morceaux sans avoir prouve qu ils se recollent.
_out 'verification du recollage'
cat "$rel"/*.part > "$rel/.check.iso"
set -l check_sum (sha256sum "$rel/.check.iso" | cut -d' ' -f1)
rm -f "$rel/.check.iso"
test "$check_sum" = "$iso_sum"; or _die 'le recollage ne redonne pas l ISO — decoupe abandonnee'
_out 'ok : les morceaux se recollent a l identique'

if set -q _flag_dry_run
    _out "dry-run : fichiers prets dans $rel, rien publie"
    exit
end

# --- publication ---
_out "creation de la release $tag"
gh release create "$tag" "$rel"/*.part "$rel/SHA256SUMS" \
    --title "caelestia-wany $tag" \
    --notes-file "$root/release-notes.md"
or _die 'gh release create a echoue'

_out 'publie'
gh release view "$tag" --json url --jq .url
