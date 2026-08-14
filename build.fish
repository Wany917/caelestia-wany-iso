#!/usr/bin/env fish
# Construit l'ISO caelestia-wany de bout en bout.
#
#   1. depot pacman local des paquets AUR (pacstrap ne sait pas lire l'AUR)
#   2. mkarchiso sur le profil archiso
#
# mkarchiso doit tourner en root : le script demande sudo au moment voulu, pas avant.

argparse -n 'build.fish' 'h/help' 'skip-aur' 'clean' -- $argv
or exit 1

set -g root (realpath (dirname (status filename)))
set -g out "$root/out"
set -g work "$root/work"
set -g profile "$root/profile"

if set -q _flag_help
    echo 'usage: ./build.fish [--skip-aur] [--clean]'
    echo
    echo '  --skip-aur   reutilise le depot local existant (pas de recollecte)'
    echo '  --clean      repart de zero (depot, work/, out/)'
    exit
end

function _step -a text
    set_color -o cyan
    echo
    echo ":: $text"
    set_color normal
end

function _die -a text
    set_color -o red
    echo "!! $text" >&2
    set_color normal
    exit 1
end

# --- prerequis ---
_step 'Verification des prerequis'
for tool in mkarchiso repo-add rsync
    command -q $tool; or _die "$tool introuvable. Installe : sudo pacman -S --needed archiso devtools rsync"
end
echo "  ok  outillage present"

# Espace disque : mkarchiso decompresse tout le systeme de fichiers racine
set -l avail_gb (math (df --output=avail -k "$root" | tail -1) / 1024 / 1024)
if test $avail_gb -lt 15
    _die "seulement $avail_gb Go libres sur $root, il en faut ~15-20"
end
echo "  ok  $avail_gb Go libres"

if set -q _flag_clean
    _step 'Nettoyage'
    rm -rf "$work" "$out"
    echo "  work/ et out/ supprimes"
end

# --- 1. depot AUR local ---
if set -q _flag_skip_aur
    test -f "$root/local-repo/caelestia-wany.db.tar.zst"
    or _die "--skip-aur demande mais aucun depot local existant"
    _step 'Depot AUR local : reutilise (--skip-aur)'
else
    _step 'Depot AUR local'
    set -l aur_args
    set -q _flag_clean; and set aur_args --clean
    fish "$root/scripts/build-aur-repo.fish" $aur_args
    or _die 'construction du depot AUR echouee'
end

# --- 2. profil archiso ---
_step 'Profil archiso'
fish "$root/scripts/make-profile.fish"
or _die 'generation du profil echouee'

# --- 3. ISO ---
_step 'Construction de l\'ISO (mkarchiso, root requis)'
mkdir -p "$out"
sudo mkarchiso -v -w "$work" -o "$out" "$profile"
or _die 'mkarchiso a echoue'

_step 'Termine'
ls -lh "$out"/*.iso 2>/dev/null | sed 's/^/  /'
