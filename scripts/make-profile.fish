#!/usr/bin/env fish
# Genere profile/ = le profil releng d'archiso + notre overlay.
#
# profile/ est entierement regenere a chaque appel et n'est pas versionne : seul
# overlay/ l'est. Notre difference avec releng reste ainsi explicite et se reapplique
# telle quelle quand archiso met releng a jour.

argparse -n 'make-profile.fish' 'h/help' 'rice=' -- $argv
or exit 1

set -g root (realpath (dirname (status filename))/..)
set -g releng /usr/share/archiso/configs/releng
set -g profile "$root/profile"
set -g overlay "$root/overlay"
set -g repo_dir "$root/local-repo"
set -g repo_name caelestia-wany

# Depot du rice a embarquer dans l'image
set -g rice_src "$HOME/.local/share/caelestia"
set -q _flag_rice; and set rice_src (realpath $_flag_rice)

if set -q _flag_help
    echo 'usage: scripts/make-profile.fish [--rice <chemin>]'
    echo
    echo "  --rice   depot caelestia-wany a embarquer (defaut : $rice_src)"
    exit
end

function _out -a text
    set_color cyan; echo "[profile] $text"; set_color normal
end
function _die -a text
    set_color -o red; echo "[profile] $text" >&2; set_color normal; exit 1
end

test -d "$releng"; or _die "profil releng introuvable. Installe : sudo pacman -S archiso"
test -d "$rice_src"; or _die "depot du rice introuvable : $rice_src"
test -f "$repo_dir/$repo_name.db.tar.zst"; or _die "depot local absent. Lance d'abord scripts/build-aur-repo.fish"

# --- base releng ---
_out "copie de releng"
rm -rf "$profile"
cp -r "$releng" "$profile"

# --- paquets ---
_out "ajout de nos paquets"
begin
    echo
    echo "# --- caelestia-wany ---"
    cat "$overlay/packages.extra"
end >> "$profile/packages.x86_64"

# --- depot local, cote build ---
# mkarchiso lit ce fichier pour peupler l'airootfs. Le chemin est absolu et propre
# a cette machine : c'est sans importance, profile/ est regenere a chaque build.
_out "declaration du depot local dans pacman.conf"
begin
    echo
    echo "[$repo_name]"
    echo "SigLevel = Optional TrustAll"
    echo "Server = file://$repo_dir"
end >> "$profile/pacman.conf"

# --- overlay airootfs ---
_out "application de l'overlay airootfs"
cp -r "$overlay/airootfs/." "$profile/airootfs/"

# Activation des services (archiso ne lance pas systemctl enable : on cree les
# liens de wants a la main)
set -l wants "$profile/airootfs/etc/systemd/system/multi-user.target.wants"
mkdir -p "$wants"
ln -sf /etc/systemd/system/caelestia-live-setup.service "$wants/caelestia-live-setup.service"
ln -sf /usr/lib/systemd/system/greetd.service "$wants/greetd.service"

# greetd occupe le VT1. L'autologin root d'archiso s'y installe aussi et les deux
# se disputeraient le terminal : on neutralise getty@tty1. Les autres VT restent
# disponibles (Ctrl+Alt+F2) si le bureau ne demarre pas.
ln -sf /dev/null "$profile/airootfs/etc/systemd/system/getty@tty1.service"

# --- rice embarque dans l'image ---
# Dans le home de l'utilisateur live, pas dans /root : Hyprland refuse de tourner
# en root, la session live passe donc par un vrai utilisateur.
_out "integration du rice depuis $rice_src"
set -l dst "$profile/airootfs/home/caelestia/.local/share/caelestia"
mkdir -p (dirname "$dst")
# .git exclu : plusieurs dizaines de Mo d'historique inutiles dans une image live
rsync -a --exclude '.git' --exclude 'local-repo' "$rice_src/" "$dst/"

# --- identite de l'ISO ---
_out "personnalisation de profiledef.sh"
sed -i \
    -e 's|^iso_name=.*|iso_name="caelestia-wany"|' \
    -e 's|^iso_label=.*|iso_label="CAELESTIA_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"|' \
    -e 's|^iso_publisher=.*|iso_publisher="caelestia by soramanew <https://github.com/caelestia-dots>"|' \
    -e 's|^iso_application=.*|iso_application="caelestia-wany live"|' \
    "$profile/profiledef.sh"

# Droits d'execution. mkarchiso copie l'airootfs avec 'cp -af --no-preserve=mode' :
# TOUT le bit +x est perdu, seuls les chemins listes dans file_permissions le
# retrouvent. Ca vaut pour nos scripts comme pour ceux du rice.
set -l perms
for f in (find "$overlay/airootfs/usr/local/bin" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null)
    set -a perms "  [\"/usr/local/bin/$f\"]=\"0:0:755\""
end
test (count $perms) -gt 0; or _die "aucun script trouve dans overlay/airootfs/usr/local/bin"

# Executables du rice. La liste est derivee du depot source, ou les bits sont
# justes, donc elle suit automatiquement les evolutions du rice.
# Deux d'entre eux sont indispensables : hypr/scripts/configs.fish, appele par
# hyprland.conf pour creer les ~/.config/caelestia/hypr-*.conf (sans lui, Hyprland
# affiche 'source= globbing error'), et wsaction.fish pour les raccourcis de
# workspace. Le proprietaire est corrige plus tard par caelestia-apply-rice.
set -l rice_bins
for f in (find "$rice_src" -type f -perm -u+x -not -path '*/.git/*' -printf '%P\n' 2>/dev/null)
    set -a perms "  [\"/home/caelestia/.local/share/caelestia/$f\"]=\"0:0:755\""
    set -a rice_bins $f
end
echo "  ok  "(count $rice_bins)" executable(s) du rice preserves"

printf '%s\n' $perms > /tmp/cw-perms.$fish_pid
sed -i "/^  \[\"\/usr\/local\/bin\/choose-mirror\"\]=/r /tmp/cw-perms.$fish_pid" "$profile/profiledef.sh"
rm -f /tmp/cw-perms.$fish_pid

# Verifie que chaque entree est bien declaree, plutot que de supposer que le sed a pris
for f in (find "$overlay/airootfs/usr/local/bin" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null)
    grep -q "\"/usr/local/bin/$f\"" "$profile/profiledef.sh"
    or _die "droits non declares pour $f : la structure de profiledef.sh a change"
end
for f in $rice_bins
    grep -qF "caelestia/$f\"" "$profile/profiledef.sh"
    or _die "droits non declares pour le rice : $f"
end
echo "  ok  "(count $perms)" entree(s) de droits declarees"

# --- validation de la liste de paquets ---
# mkarchiso analyse packages.x86_64 avec ce sed : il retire "#..." mais laisse les
# espaces qui precedaient, et pacman refuse un nom avec des espaces en fin. On
# valide ici plutot que de le decouvrir a la moitie d'un build de 30 minutes.
_out "validation des noms de paquets"
set -l tmp (mktemp -d)
begin
    sed -n '/^\[options\]/,/^$/p' /etc/pacman.conf | grep -vE '^(HookDir|CacheDir)'
    echo 'SigLevel = Never'
    for r in core extra multilib
        echo; echo "[$r]"; echo 'Include = /etc/pacman.d/mirrorlist'
    end
    echo; echo "[$repo_name]"; echo "Server = file://$repo_dir"
end > "$tmp/pacman.conf"
mkdir -p "$tmp/db"
fakeroot pacman --config "$tmp/pacman.conf" --dbpath "$tmp/db" -Sy >/dev/null 2>&1

set -l bad
for p in (sed '/^[[:blank:]]*#.*/d;s/#.*//;/^[[:blank:]]*$/d' "$profile/packages.x86_64")
    pacman --config "$tmp/pacman.conf" --dbpath "$tmp/db" -Si "$p" >/dev/null 2>&1
    or set -a bad "[$p]"
end
rm -rf "$tmp"

if test (count $bad) -gt 0
    _die "paquets non resolvables (crochets = bornes du nom, espaces inclus) : $bad"
end
echo "  ok  tous les paquets se resolvent"

_out "profil pret : $profile"
echo "  paquets  : "(sed '/^[[:blank:]]*#.*/d;s/#.*//;/^[[:blank:]]*$/d' "$profile/packages.x86_64" | wc -l)
echo "  rice     : "(du -sh "$dst" | cut -f1)
