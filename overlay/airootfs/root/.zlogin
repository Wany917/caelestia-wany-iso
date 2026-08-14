# fix for screen readers
if grep -Fqa 'accessibility=' /proc/cmdline &> /dev/null; then
    setopt SINGLE_LINE_ZLE
fi

~/.automated_script.sh

# caelestia-wany : demarre le bureau sur le premier TTY.
#
# Volontairement sans 'exec' : si Hyprland ne demarre pas (GPU non supporte,
# pilote manquant), on retombe sur un shell utilisable au lieu d'un ecran noir.
# Sur une ISO qui doit demarrer sur du materiel inconnu, ca change tout.
if [[ -z $WAYLAND_DISPLAY && $XDG_VTNR -eq 1 ]]; then
    echo
    echo '  caelestia par soramanew et caelestia-dots  --  https://github.com/caelestia-dots'
    echo '  overlay perso : caelestia-wany'
    echo
    echo '  Demarrage du bureau...   (Ctrl+C dans les 3 s pour rester en console)'
    sleep 3
    Hyprland
fi
