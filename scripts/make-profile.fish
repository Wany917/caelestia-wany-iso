#!/usr/bin/env fish
# Genere profile/ = le profil releng d'archiso + notre overlay.
#
# profile/ est entierement regenere a chaque appel et n'est pas versionne : seul
# overlay/ l'est. Notre difference avec releng reste ainsi explicite et se reapplique
# telle quelle quand archiso met releng a jour.

argparse -n 'make-profile.fish' 'h/help' 'rice=' 'rice-ref=' -- $argv
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
# Le rice est embarque depuis un commit, jamais depuis le dossier de travail : en
# aout, la copie du dossier avait emporte des fichiers ignores par git
# (fish_variables avec des chemins de la machine de build, scheme courant...).
set -g rice_ref main
set -q _flag_rice_ref; and set rice_ref $_flag_rice_ref

if set -q _flag_help
    echo 'usage: scripts/make-profile.fish [--rice <chemin>] [--rice-ref <ref>]'
    echo
    echo "  --rice       depot caelestia-wany a embarquer (defaut : $rice_src)"
    echo "  --rice-ref   commit, branche ou tag du rice (defaut : $rice_ref)"
    exit
end

function _out -a text
    set_color cyan; echo "[profile] $text"; set_color normal
end
function _die -a text
    set_color -o red; echo "[profile] $text" >&2; set_color normal; exit 1
end

test -d "$releng"; or _die "profil releng introuvable. Installe : paru -S archiso"
test -d "$rice_src"; or _die "depot du rice introuvable : $rice_src"
git -C "$rice_src" rev-parse --verify -q "$rice_ref^{commit}" >/dev/null
or _die "ref '$rice_ref' introuvable dans $rice_src"
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
# git archive : uniquement les fichiers suivis, au commit demande. Pas de .git
# (plusieurs dizaines de Mo d'historique inutiles dans une image live).
set -l rice_commit (git -C "$rice_src" rev-parse --short "$rice_ref^{commit}")
_out "integration du rice : $rice_ref ($rice_commit) depuis $rice_src"
if test "$(git -C "$rice_src" rev-parse HEAD)" = "$(git -C "$rice_src" rev-parse "$rice_ref^{commit}")"
    set -l dirty (git -C "$rice_src" status --porcelain)
    if test (count $dirty) -gt 0
        set_color yellow
        echo "  !!  "(count $dirty)" modification(s) non commitee(s) dans le rice : elles ne seront PAS dans l'ISO"
        set_color normal
    end
end
set -l live_home "$profile/airootfs/home/caelestia"
set -l dst "$live_home/.local/share/caelestia"
mkdir -p "$dst"
git -C "$rice_src" archive "$rice_ref" | tar -x -C "$dst"
or _die "extraction du rice echouee"

# Reglages machine de la session live, lus par hypr-user.lua du rice. Pas de
# verrouillage au demarrage : le compte live n'a pas de mot de passe, l'ecran de
# verrouillage ne ferait que derouter.
# Clavier : us par defaut, fr en second, Verr. Maj basculant de l'un a l'autre.
# L'entree AZERTY du menu de demarrage inverse l'ordre (caelestia-live-setup lit
# caelestia.kb=fr). Taper une commande pour changer de disposition est quasi
# impossible quand le clavier physique ne correspond pas. Verr. Maj ne sert a
# aucun raccourci du rice, et Maj + Verr. Maj garde le verrouillage des majuscules.
mkdir -p "$live_home/.config/caelestia"
printf '%s\n' \
    '-- Live session settings, written when the ISO was built.' \
    'return {' \
    '    kb_layout     = "us,fr",' \
    '    kb_options    = "grp:caps_toggle",' \
    '    lock_on_start = false,' \
    '}' > "$live_home/.config/caelestia/hypr-local.lua"

# Attente de la synchro NTP (activee par releng pour pacman-init) : sans reseau
# elle ne finit jamais (TimeoutStartSec=infinity), le systeme reste "starting",
# pacman-init, power-profiles-daemon et multi-user.target attendent, et la console
# affiche "A start job is running for Wait Until Kernel Time Synchronized" (#1).
# L'installeur copie le live : le systeme installe en heritait aussi.
# systemd-timesyncd reste actif et regle l'heure des que le reseau arrive.
rm -f "$profile/airootfs/etc/systemd/system/sysinit.target.wants/systemd-time-wait-sync.service"
test -e "$profile/airootfs/etc/systemd/system/sysinit.target.wants/systemd-time-wait-sync.service"
and _die "systemd-time-wait-sync toujours active"

# --- identite de l'ISO ---
_out "personnalisation de profiledef.sh"
sed -i \
    -e 's|^iso_name=.*|iso_name="caelestia-wany"|' \
    -e 's|^iso_label=.*|iso_label="CAELESTIA_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"|' \
    -e 's|^iso_publisher=.*|iso_publisher="caelestia by soramanew <https://github.com/caelestia-dots>"|' \
    -e 's|^iso_application=.*|iso_application="caelestia-wany live"|' \
    "$profile/profiledef.sh"

# Menu de demarrage : "caelestia-wany live" plutot que "Arch Linux install
# medium", qui laissait croire a l'ISO officielle d'Arch.
_out "menu de demarrage"
set -l boot_cfgs $profile/efiboot/loader/entries/*.conf $profile/grub/*.cfg $profile/syslinux/*.cfg
sed -i 's/Arch Linux install medium/caelestia-wany live/g' $boot_cfgs
if grep -l 'Arch Linux install medium' $boot_cfgs >/dev/null
    _die "entrees de demarrage non renommees : la structure de releng a change"
end

# Choix du clavier au demarrage : l'entree principale devient "QWERTY / US" (par
# defaut), et une copie "AZERTY / FR" passe caelestia.kb=fr (lu par
# caelestia-live-setup et caelestia-install) et vconsole.keymap=fr (consoles TTY).
# systemd-boot et syslinux sont les modes de demarrage de releng ; les deux
# fichiers GRUB servent au demarrage en loopback (Ventoy).
_out "entrees QWERTY / AZERTY"
set -l kb_params 'caelestia.kb=fr vconsole.keymap=fr'
set -l sdboot $profile/efiboot/loader/entries
sed -e 's|^title \(.*\)caelestia-wany live (|title \1caelestia-wany live, AZERTY / FR (|' \
    -e 's|^sort-key .*|sort-key 01b|' \
    -e "s| %KERNEL_PARAMS%| $kb_params %KERNEL_PARAMS%|" \
    $sdboot/01-archiso-linux.conf > $sdboot/01b-archiso-linux-azerty.conf
sed -i 's|^title \(.*\)caelestia-wany live (|title \1caelestia-wany live, QWERTY / US (|' $sdboot/01-archiso-linux.conf
for f in $profile/grub/grub.cfg $profile/grub/loopback.cfg
    KB="$kb_params" perl -0pi -e '
        s{(menuentry "caelestia-wany live)( \(%ARCH%, [^\n]*--id \x27archlinux\x27 \{\n.*?\n\}\n)}{
            my ($head, $rest) = ($1, $2);
            (my $fr = "$head, AZERTY / FR$rest") =~ s/--id \x27archlinux\x27/--id \x27archlinux-azerty\x27/;
            $fr =~ s/ %KERNEL_PARAMS%/ $ENV{KB} %KERNEL_PARAMS%/;
            "$head, QWERTY / US$rest\n$fr"
        }se' $f
end
KB="$kb_params" perl -0pi -e '
    s{(LABEL arch\n.*?MENU LABEL caelestia-wany live)( \(%ARCH%, BIOS\)\n.*?%KERNEL_PARAMS%\n)}{
        my ($head, $rest) = ($1, $2);
        (my $fr = "$head, AZERTY / FR$rest") =~ s/^LABEL arch$/LABEL archfr/m;
        $fr =~ s/ %KERNEL_PARAMS%/ $ENV{KB} %KERNEL_PARAMS%/;
        "$head, QWERTY / US$rest\n$fr"
    }se' $profile/syslinux/archiso_sys-linux.cfg
for f in $sdboot/01-archiso-linux.conf $sdboot/01b-archiso-linux-azerty.conf $profile/grub/grub.cfg $profile/grub/loopback.cfg $profile/syslinux/archiso_sys-linux.cfg
    set -l n (string match -r -- 'caelestia\.kb=fr' < $f | count)
    set -l expected 1
    string match -q -- '*-linux.conf' $f; and set expected 0
    test "$n" = "$expected"; or _die "entree AZERTY absente ou en double dans "(basename $f)" : la structure de releng a change"
end

# Ce qui a servi a construire l'image, pour les rapports de bug :
#   cat /etc/caelestia-wany-release
set -l iso_commit (git -C "$root" rev-parse --short HEAD)
test -n "$(git -C "$root" status --porcelain -- overlay scripts)"; and set iso_commit "$iso_commit-dirty"
printf '%s\n' \
    "ISO_COMMIT=$iso_commit" \
    "RICE_REF=$rice_ref" \
    "RICE_COMMIT=$rice_commit" \
    "BUILD_DATE="(date -u +%Y-%m-%dT%H:%MZ) > "$profile/airootfs/etc/caelestia-wany-release"

# Droits d'execution. mkarchiso copie l'airootfs avec 'cp -af --no-preserve=mode' :
# TOUT le bit +x est perdu, seuls les chemins listes dans file_permissions le
# retrouvent. Ca vaut pour nos scripts comme pour ceux du rice.
set -l perms
for f in (find "$overlay/airootfs/usr/local/bin" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null)
    set -a perms "  [\"/usr/local/bin/$f\"]=\"0:0:755\""
end
test (count $perms) -gt 0; or _die "aucun script trouve dans overlay/airootfs/usr/local/bin"

# Home de l'utilisateur live, en RECURSIF (le slash final declenche chown -fhR
# et chmod -fR dans mkarchiso).
#
# Une seule entree regle deux problemes d'un coup :
#   - le proprietaire. Sans elle, le home appartient a root, et si la mise en
#     place au demarrage ne passe pas, Hyprland echoue sur "Couldn't create config
#     home directory (Permission denied)" (issue #2). L'UID 1000 est fixe par
#     /etc/sysusers.d/caelestia-live.conf. Fixer l'etat dans l'image evite de
#     dependre du service de demarrage pour ca.
#   - le bit +x, que mkarchiso jette (cp --no-preserve=mode). Il faut le rendre a
#     hypr/scripts/configs.fish, sans quoi Hyprland ne trouve pas les fichiers
#     qu'il tente de sourcer, et a wsaction.fish pour les raccourcis de workspace.
#
# 755 partout dans le home : c'est une session live sans secret, et ca evite
# d'enumerer les executables un par un — donc rien a oublier quand le rice evolue.
set -a perms "  [\"/home/caelestia/\"]=\"1000:1000:755\""

printf '%s\n' $perms > /tmp/cw-perms.$fish_pid
sed -i "/^  \[\"\/usr\/local\/bin\/choose-mirror\"\]=/r /tmp/cw-perms.$fish_pid" "$profile/profiledef.sh"
rm -f /tmp/cw-perms.$fish_pid

# Verifie que chaque entree est bien declaree, plutot que de supposer que le sed a pris
for f in (find "$overlay/airootfs/usr/local/bin" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null)
    grep -q "\"/usr/local/bin/$f\"" "$profile/profiledef.sh"
    or _die "droits non declares pour $f : la structure de profiledef.sh a change"
end
# Le home doit etre declare EN RECURSIF (slash final) et appartenir a l'UID que
# sysusers attribue : sans ca, Hyprland ne peut pas ecrire dans son propre home.
grep -qF '["/home/caelestia/"]="1000:1000:755"' "$profile/profiledef.sh"
or _die 'droits du home live non declares, ou UID/mode inattendus'
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
# --disable-sandbox : le bac a sable du telechargeur de pacman 7 echoue sous fakeroot
fakeroot pacman --config "$tmp/pacman.conf" --dbpath "$tmp/db" --disable-sandbox -Sy >/dev/null 2>&1

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
