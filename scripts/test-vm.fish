#!/usr/bin/env fish
# Lance l'ISO dans QEMU pour la tester sans toucher a la machine.
#
#   --live      demarre l'ISO seule (defaut) : verifie que le bureau s'affiche
#   --install   demarre l'ISO avec un disque virtuel vierge : pour derouler
#               caelestia-install dedans
#   --disk      demarre le disque installe sans l'ISO : verifie le resultat
#
#   --offline   coupe le reseau de la VM. C'est LE test qui prouve que
#               l'installation hors-ligne tient vraiment.
#   --display   vnc (defaut, aucun paquet a installer) ou gtk (fenetre native,
#               demande qemu-ui-gtk)
#
# Tout se passe dans vm/ : rien n'est ecrit en dehors.

argparse -n 'test-vm.fish' 'h/help' 'live' 'install' 'disk' 'offline' 'display=' 'size=' -- $argv
or exit 1

set -g root (realpath (dirname (status filename))/..)
set -g vm "$root/vm"
# find plutot qu'un glob : fish erre sur un motif sans correspondance, et
# l'ISO n'existe pas encore tant que le build tourne.
set -g iso (find "$root/out" -maxdepth 1 -name '*.iso' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
set -g disk "$vm/disk.qcow2"
set -g vars "$vm/OVMF_VARS.fd"
set -g ovmf_code /usr/share/edk2/x64/OVMF_CODE.4m.fd
set -g ovmf_vars /usr/share/edk2/x64/OVMF_VARS.4m.fd
set -g size 30G
set -q _flag_size; and set size $_flag_size

if set -q _flag_help
    echo 'usage: scripts/test-vm.fish [--live|--install|--disk] [--offline] [--display vnc|gtk] [--size 30G]'
    exit
end

function _out -a text
    set_color cyan; echo "[vm] $text"; set_color normal
end
function _die -a text
    set_color -o red; echo "[vm] $text" >&2; set_color normal; exit 1
end

# --- mode ---
set -l mode live
set -q _flag_install; and set mode install
set -q _flag_disk; and set mode disk

# --- affichage ---
set -l display vnc
if set -q _flag_display
    set display $_flag_display
else if qemu-system-x86_64 -display help 2>&1 | grep -qw gtk
    set display gtk
end
if test "$display" = gtk
    qemu-system-x86_64 -display help 2>&1 | grep -qw gtk
    or _die "affichage gtk indisponible. Installe qemu-ui-gtk, ou utilise --display vnc"
end

# --- verifications ---
test -f "$ovmf_code"; or _die "firmware UEFI absent : $ovmf_code (paquet edk2-ovmf)"
if test "$mode" != disk
    test -n "$iso"; or _die "aucune ISO dans $root/out — lance d'abord le build"
end

mkdir -p "$vm"
# Les variables UEFI sont propres a la VM : on part d'une copie neuve
test -f "$vars"; or cp "$ovmf_vars" "$vars"

# --- disque ---
if test "$mode" != live
    if not test -f "$disk"
        _out "creation du disque virtuel ($size)"
        qemu-img create -f qcow2 "$disk" "$size" >/dev/null
    end
end

# --- assemblage de la commande ---
# Le monitor sur socket unix permet de piloter la VM sans clavier : notamment
# 'screendump' pour capturer l'ecran et constater ce qui s'affiche vraiment,
# plutot que de se fier a une description.
set -l args \
    -enable-kvm -cpu host -smp 4 -m 8G \
    -machine q35 \
    -monitor unix:$vm/monitor.sock,server,nowait \
    -drive if=pflash,format=raw,readonly=on,file=$ovmf_code \
    -drive if=pflash,format=raw,file=$vars \
    -device intel-hda -device hda-duplex \
    -usb -device usb-tablet

# Carte graphique : virtio-gpu si disponible (bien plus fluide), sinon la VGA
# standard, pilotee cote noyau par bochs-drm. Hyprland exige un peripherique
# DRM/KMS et bochs-drm en est un ; le rendu passe simplement par llvmpipe.
# qemu-base ne fournit PAS virtio-vga, il faut qemu-desktop pour l'avoir.
if qemu-system-x86_64 -device help 2>&1 | grep -q '"virtio-vga"'
    set -a args -device virtio-vga
else
    set -a args -vga std
    _out 'virtio-gpu absent (qemu-base) : VGA standard + rendu logiciel, ce sera lent'
end

# Reseau : le mode hors-ligne est le test qui prouve la promesse offline
if set -q _flag_offline
    set -a args -nic none
    _out 'reseau DESACTIVE (test hors-ligne)'
else
    set -a args -nic user,model=virtio-net-pci
end

switch $mode
    case live
        set -a args -cdrom "$iso" -boot d
        _out "demarrage de l'ISO : "(basename "$iso")
    case install
        set -a args -cdrom "$iso" -boot d -drive file=$disk,if=virtio,format=qcow2
        _out "ISO + disque vierge. Dans la VM : sudo caelestia-install"
    case disk
        set -a args -drive file=$disk,if=virtio,format=qcow2
        _out 'demarrage du disque installe (sans ISO)'
end

switch $display
    case gtk
        set -a args -display gtk
    case vnc
        set -a args -display none -vnc :1
        _out 'VNC sur localhost:5901 — connecte-toi avec : remmina vnc://localhost:5901'
end

_out 'Ctrl+C ici pour arreter la VM'
echo
qemu-system-x86_64 $args
