#!/usr/bin/env python3
"""Capture l'ecran de la VM de test via le monitor QEMU.

    scripts/vm-screenshot.py [sortie.png]

Passe par le socket unix du monitor (HMP). Utile pour constater ce que la VM
affiche reellement, au lieu de se fier a une description.
"""
import os
import socket
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOCK = os.path.join(ROOT, "vm", "monitor.sock")
out_png = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "vm", "screen.png"))
out_ppm = out_png.replace(".png", ".ppm")

if not os.path.exists(SOCK):
    sys.exit(f"monitor introuvable : {SOCK} (la VM tourne-t-elle ?)")

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.settimeout(10)
s.connect(SOCK)
time.sleep(0.3)
try:  # vide la banniere du monitor
    s.recv(65536)
except socket.timeout:
    pass

if os.path.exists(out_ppm):
    os.remove(out_ppm)
s.sendall(f"screendump {out_ppm}\n".encode())
time.sleep(1.5)
s.close()

if not os.path.exists(out_ppm):
    sys.exit("screendump n'a rien produit")

# Le PPM n'est pas lisible par les outils d'image courants : on convertit.
subprocess.run(["magick", out_ppm, out_png], check=True)
os.remove(out_ppm)
print(out_png)
