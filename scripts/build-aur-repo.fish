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

# Cherche le paquet a embarquer pour un nom donne : la version INSTALLEE ici (le
# binaire qui tourne et a ete eprouve), sinon la plus haute du cache. pkgbuilds/
# contient les paquets dont la version AUR ne se construit plus (makepkg y depose
# le .pkg.tar.zst).
# Exclut les paquets -debug (generes a cote, inutiles et volumineux).
#
# A version egale, le fichier le plus recent gagne : un 'paru --rebuild' garde le
# meme nom de fichier, et /var/cache/pacman/pkg conserve l'ancienne copie (pacstrap
# y depose ce qu'il installe pendant le build de l'ISO). Trier par chemin faisait
# gagner cette vieille copie.
function _find_pkg -a name
    set -l dirs "$HOME/.cache/paru/clone/$name" "$root/pkgbuilds/$name" /var/cache/pacman/pkg
    set -l ver (pacman -Q $name 2>/dev/null | string split ' ')[2]
    set -l pattern "$name-[0-9r]*.pkg.tar.zst"
    test -n "$ver"; and set pattern "$name-$ver-*.pkg.tar.zst"
    set -l found
    for d in $dirs
        test -d "$d"; or continue
        set -a found (find "$d" -maxdepth 1 -name "$pattern" ! -name '*-debug-*' 2>/dev/null)
    end
    test (count $found) -gt 0; or return 1
    if test -n "$ver"
        ls -t $found | head -1
    else
        # tri par version : le nom de fichier porte pkgver-pkgrel
        printf '%s\n' $found | sort -V | tail -1
    end
end

# Version de Qt dont un paquet a utilise les en-tetes PRIVES : leur chemin,
# /usr/include/qt6/<Module>/<version>/, reste grave dans le binaire. Ces paquets
# (quickshell) plantent des que Qt change, meme d'une version mineure. Rien en
# sortie = pas d'API privee, le paquet survit aux mises a jour de Qt.
function _qt_private_version -a pkgfile
    set -l tmp (mktemp -d)
    bsdtar -xf "$pkgfile" -C "$tmp" usr 2>/dev/null
    find "$tmp" -type f -exec grep -aohE '/usr/include/qt6/Qt[A-Za-z]+/6\.[0-9]+\.[0-9]+/' {} + 2>/dev/null \
        | string match -r '6\.[0-9]+\.[0-9]+' | sort -u
    rm -rf "$tmp"
end

# Bibliotheques (NEEDED des ELF du paquet) que ni le paquet lui-meme ni cette
# machine ne fournissent. Lecture seule, rien n'est execute. Les paquets AUR
# embarques sont ceux installes ici, donc leurs dependances aussi.
function _missing_libs -a pkgfile
    set -l tmp (mktemp -d)
    bsdtar -xf "$pkgfile" -C "$tmp" usr opt 2>/dev/null
    set -l own (find "$tmp" -name '*.so*' -printf '%f\n')
    set -l needed (find "$tmp" -type f -exec env LC_ALL=C readelf -d {} + 2>/dev/null \
        | string match -r '\(NEEDED\).*\[(.+)\]' | string match -rv NEEDED | sort -u)
    rm -rf "$tmp"
    for lib in $needed
        contains -- $lib $own; and continue
        contains -- $lib $system_libs; or echo $lib
    end
end

test -f "$conf"; or _die "liste des paquets introuvable : $conf"

if set -q _flag_clean
    _out yellow "nettoyage de $repo_dir"
    rm -rf "$repo_dir"
end
mkdir -p "$repo_dir"
# Le depot repart de zero a chaque fois : repo-add indexe tout le dossier, donc un
# ancien fichier (paquet retire de la liste, version depassee) finissait dans la
# base. La copie coute quelques secondes.
find "$repo_dir" -maxdepth 1 \( -name '*.pkg.tar.zst' -o -name "$repo_name.*" \) -delete

# Liste des paquets. Retire les commentaires de fin de ligne AVANT de trim :
# sinon "quickshell-git  # commentaire" devient un nom de paquet invalide.
set -l packages (string replace -r '#.*$' '' < "$conf" | string trim | string match -rv '^$')
_out cyan "depot '$repo_name' : "(count $packages)" paquets attendus"

set -l missing
set -l collected
for p in $packages
    set -l f (_find_pkg $p)
    if test -z "$f"
        set -a missing $p
        set_color red; echo "  manquant  $p"; set_color normal
    else
        cp "$f" "$repo_dir/"
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

# Paquets compiles contre un autre Qt que celui qui ira dans l'ISO. mkarchiso
# installe le Qt du jour (build.fish verifie que cette machine est a jour, donc
# c'est aussi le sien) : un quickshell compile avant la derniere mise a jour de Qt
# ne demarrerait pas, et l'ISO s'ouvrirait sur un bureau vide.
set -l qt (pacman -Q qt6-base 2>/dev/null | string split ' ')[2]
set qt (string replace -r -- '-[^-]+$' '' "$qt")
#
# Et paquets qui reclament une bibliotheque partagee absente d'ici : une
# dependance a change de soname sans que le paquet soit recompile. Vecu deux fois
# (17 septembre, 16 octobre) : libcava 1.0 remplace libcava.so.0 par .so.1, et
# caelestia-shell 1.6.2, compile contre .so.0, ne charge plus. Le shell ne demarre
# pas, l'ISO s'ouvre sur un ecran noir.
set -g system_libs (ldconfig -p | string match -r '^\s+(\S+) ' | string match -rv '^\s')
set -l stale
set -l broken
for f in $repo_dir/*.pkg.tar.zst
    string match -q -- '*-any.pkg.tar.zst' $f; and continue
    set -l name (bsdtar -xOf "$f" .PKGINFO | string match -r '^pkgname = (.+)')[2]
    for v in (_qt_private_version "$f")
        if test "$v" != "$qt"
            set -a stale $name
            set_color red; echo "  qt        $name compile contre Qt $v, l'ISO aura Qt $qt"; set_color normal
        end
    end
    set -l miss (_missing_libs "$f")
    if test (count $miss) -gt 0
        set -a broken $name
        set_color red; echo "  libs      $name reclame $miss, introuvable(s) ici"; set_color normal
    end
end
if test (count $stale) -gt 0
    echo
    _out yellow "Recompile-les contre le Qt actuel, puis relance :"
    echo "    paru -S --rebuild --noconfirm $stale"
    echo
    _die (count $stale)" paquet(s) a recompiler"
end
echo "  ok        API privee de Qt alignee sur Qt $qt"
if test (count $broken) -gt 0
    echo
    _out yellow "Une dependance a change de version sans que ces paquets suivent. Soit tu"
    _out yellow "recompiles (paru -S --rebuild $broken), soit tu reviens a l'ancienne"
    _out yellow "version de la dependance, puis relance."
    echo
    _die (count $broken)" paquet(s) avec des bibliotheques manquantes"
end
echo "  ok        toutes les bibliotheques requises sont presentes"

# Construit la base de donnees pacman du depot, vierge (videe plus haut avec les
# paquets) : elle ne contient que ce qui vient d'etre collecte.
_out cyan "generation de la base $repo_name.db.tar.zst"
repo-add --quiet --new --remove "$repo_dir/$repo_name.db.tar.zst" "$repo_dir"/*.pkg.tar.zst
or _die "repo-add a echoue"

_out green "depot pret : $repo_dir ("(du -sh "$repo_dir" | cut -f1)")"
