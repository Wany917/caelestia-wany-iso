# fix for screen readers
if grep -Fqa 'accessibility=' /proc/cmdline &> /dev/null; then
    setopt SINGLE_LINE_ZLE
fi

~/.automated_script.sh

# Le bureau n'est plus lance ici : greetd s'en charge pour l'utilisateur
# 'caelestia'. Hyprland refuse de demarrer en root, et ce fichier appartient a
# la session root d'archiso.
