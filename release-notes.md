An Arch Linux ISO that boots straight into **[caelestia](https://github.com/caelestia-dots/caelestia)** by [@soramanew](https://github.com/soramanew) and the caelestia-dots team, pre-configured with the [caelestia-wany](https://github.com/Wany917/caelestia-wany) overlay.

**All credit for the desktop goes to caelestia.** This image contains no desktop of its own — it packages caelestia's work into something installable. If you like what you see when it boots, that is their work: please star and support the original project.

## Getting the ISO

GitHub caps release files at 2 GiB and the image is larger, so it is split. Download every `.part` file plus `SHA256SUMS`, then reassemble:

```sh
cat caelestia-wany-*.iso.*.part > caelestia-wany.iso
sha256sum -c SHA256SUMS --ignore-missing
```

`SHA256SUMS` carries the checksum of each part *and* of the reassembled image, so you can tell a bad download from a bad reassembly. The split was verified to reassemble byte-for-byte before publishing.

Write it to a USB stick:

```sh
sudo dd if=caelestia-wany.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

## What you get

Boot it and you land in caelestia's Hyprland desktop. Install it to disk with `caelestia-install` and the same desktop comes back on first login — **no network needed at any point**, because the installer copies the live system rather than downloading packages.

The installer wipes the disk you point it at. It refuses to run outside the live session, refuses on a BIOS-booted machine rather than leaving you unbootable, refuses the disk carrying the live medium, and makes you retype the device path before touching anything.

## Worth knowing

**No editor is included.** `Super + C` is bound to `code`, but Microsoft's VS Code build is under a commercial licence that forbids redistribution. `paru` is on the image — `paru -S visual-studio-code-bin`, or `paru -S vscodium-bin` for the free build.

**No wallpaper is included.** You get a plain background until you set one (`Super + Shift + W`, or drop images in `~/Pictures/Wallpapers`).

**Some settings are personal.** Monitor layout, avatar, keybinds. See [Making it yours](https://github.com/Wany917/caelestia-wany#making-it-yours).

**This is a snapshot.** `quickshell-git` and `qtengine-git` track a moving upstream, so an image drifts from the day it was built. Rebuild rather than treating one as evergreen.
