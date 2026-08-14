#!/usr/bin/env python3
"""Envoie des touches a la VM de test via le monitor QEMU.

    scripts/vm-type.py 'systemctl status greetd'     # tape le texte + Entree
    scripts/vm-type.py --key ctrl-alt-f2             # envoie une touche brute

Sert a interroger la VM quand l'ecran ne dit rien : basculer de console, se
connecter, lancer une commande, puis capturer le resultat.

Le clavier de la console live est en disposition us (archiso ne definit pas de
KEYMAP), c'est donc la table utilisee ici.
"""
import os
import socket
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOCK = os.path.join(ROOT, "vm", "monitor.sock")

# Caracteres dont le nom QEMU differe du caractere lui-meme
NAMED = {
    " ": "spc", "-": "minus", ".": "dot", "/": "slash", ",": "comma",
    ";": "semicolon", "'": "apostrophe", "=": "equal", "[": "bracket_left",
    "]": "bracket_right", "\\": "backslash", "`": "grave_accent",
}
# Caracteres obtenus avec shift (disposition us)
SHIFTED = {
    "|": "backslash", "_": "minus", ":": "semicolon", '"': "apostrophe",
    "?": "slash", "+": "equal", "~": "grave_accent", "<": "comma", ">": "dot",
    "!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7",
    "*": "8", "(": "9", ")": "0",
}


def keys_for(text):
    for ch in text:
        if ch in SHIFTED:
            yield f"shift-{SHIFTED[ch]}"
        elif ch in NAMED:
            yield NAMED[ch]
        elif ch.isupper():
            yield f"shift-{ch.lower()}"
        else:
            yield ch


def main():
    if not os.path.exists(SOCK):
        sys.exit(f"monitor introuvable : {SOCK} (la VM tourne-t-elle ?)")

    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)

    if args[0] == "--key":
        seq = args[1:]
        enter = False
    else:
        seq = list(keys_for(args[0]))
        enter = True

    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(10)
    s.connect(SOCK)
    time.sleep(0.3)
    try:
        s.recv(65536)
    except socket.timeout:
        pass

    for k in seq:
        s.sendall(f"sendkey {k}\n".encode())
        time.sleep(0.05)
    if enter:
        s.sendall(b"sendkey ret\n")
    time.sleep(0.3)
    s.close()
    print(f"{len(seq)} touche(s) envoyee(s)")


main()
