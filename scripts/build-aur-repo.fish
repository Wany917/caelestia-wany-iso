#!/usr/bin/env fish
# Assemble le depot pacman local consomme par le profil archiso.
#
# pacstrap ne sait pas installer depuis l'AUR. Pour que l'ISO puisse installer le
# rice hors-ligne, les paquets AUR doivent etre pre-compiles et servis par un depot
# local embarque dans l'image.
#
# Les paquets sont repris dans les caches de la machine de build (paru + pacman) :
# ce sont donc exactement les binaires qui tournent ici, pas des rebuilds a l'aveugle.
# Un paquet absent du cache n'est PAS compile en douce : le script s'arrete et donne
# la commande a lancer. Compiler quickshell-git prend ~30-60 min, ca ne doit pas
# demarrer par surprise au milieu d'un build d'ISO.

argparse -n 'build-aur-repo.fish' 'h/help' 'clean' -- $argv
or exit 1

set -g root (realpath (dirname (status filename))/..)
set -g repo_name caelestia-wany
set -g repo_dir "$root/local-repo"
set -g conf "$root/aur-packages.conf"

if set -q _flag_help
    echo 'usage: scripts/build-aur-repo.fish [--clean]'
    echo
    echo '  --clean   vide le depot avant de le reconstruire'
    echo
    echo "Lit la liste des paquets dans $conf"
    exit
end

function _out -a colour text
    set_color $colour
    echo "[aur-repo] $text"
    set_color normal
end

function _die -a text
    set_color -o red
    echo "[aur-repo] $text" >&2
    set_color normal
    exit 1
end

# Cherche le paquet compile le plus recent pour un nom donne.
# Exclut les paquets -debug (generes a cote, inutiles et volumineux).
function _find_pkg -a name
    set -l dirs "$HOME/.cache/paru/clone/$name" /var/cache/pacman/pkg
    set -l found
    for d in $dirs
        test -d "$d"; or continue
        for f in (find "$d" -maxdepth 1 -name "$name-[0-9r]*.pkg.tar.zst" ! -name '*-debug-*' 2>/dev/null)
            set -a found "$f"
        end
    end
    test (count $found) -gt 0; or return 1
    # tri par version : le nom de fichier porte pkgver-pkgrel
    printf '%s\n' $found | sort -V | tail -1
end

test -f "$conf"; or _die "liste des paquets introuvable : $conf"

if set -q _flag_clean
    _out yellow "nettoyage de $repo_dir"
    rm -rf "$repo_dir"
end
mkdir -p "$repo_dir"

# Liste des paquets (commentaires et lignes vides ignores)
set -l packages (string trim < "$conf" | string match -rv '^\s*(#|$)')
_out cyan "depot '$repo_name' : "(count $packages)" paquets attendus"

set -l missing
set -l collected
for p in $packages
    set -l f (_find_pkg $p)
    if test -z "$f"
        set -a missing $p
        set_color red; echo "  manquant  $p"; set_color normal
    else
        cp -u "$f" "$repo_dir/"
        set -a collected (basename "$f")
        echo "  ok        "(basename "$f")
    end
end

if test (count $missing) -gt 0
    echo
    _out yellow "Paquets absents des caches. Compile-les puis relance :"
    echo "    paru -S --rebuild --noconfirm $missing"
    echo
    _die (count $missing)" paquet(s) manquant(s), depot incomplet"
end

# Construit la base de donnees pacman du depot
_out cyan "generation de la base $repo_name.db.tar.zst"
repo-add --quiet --new --remove "$repo_dir/$repo_name.db.tar.zst" "$repo_dir"/*.pkg.tar.zst
or _die "repo-add a echoue"

_out green "depot pret : $repo_dir ("(du -sh "$repo_dir" | cut -f1)")"
