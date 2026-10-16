An Arch Linux ISO that boots straight into **[caelestia](https://github.com/caelestia-dots/caelestia)** by [@soramanew](https://github.com/soramanew) and the caelestia-dots team, pre-configured with the [caelestia-wany](https://github.com/Wany917/caelestia-wany) overlay.

**All credit for the desktop goes to caelestia.** This image contains no desktop of its own: it packages caelestia's work into something installable. If you like what you see when it boots, that is their work. Please star and support the original project.

## Fixed since v2026.08.16

- **The live session now starts on real hardware** (#1, #2). When the machine has enough RAM, archiso copies the image to memory at boot and unmounts the USB stick. The service that prepares the live user only ran while the stick was mounted, so it was skipped: Hyprland failed with "Permission denied" and you landed on a login prompt. My test VMs booted the ISO as a CD, where this never happens. They now boot it as a USB stick.
- **The installer works in that same situation.** It used to refuse to start, and it read the kernel from the USB stick.
- **The installer is in English** and asks for your keyboard layout, which the installed desktop then uses.
- **The installed system has a login screen** (tuigreet) instead of opening the desktop without a password.
- **The live account no longer survives installation.** It was left behind and recreated at every boot.
- **Updates no longer break the desktop silently.** The installed system holds back `caelestia-shell`, `libcava` and `qt6-m3shapes-git`, whose upgrade by `paru` fails halfway and leaves a black screen. After every update, a check warns you with the exact command to run if the shell would not start (for example `quickshell-git` after a Qt update).
- Rebuilt against current Arch packages, with the Lua-based Hyprland config from upstream caelestia.

## Getting the ISO

GitHub caps release files at 2 GiB and the image is larger, so it is split. Download every `.part` file plus `SHA256SUMS`, then reassemble:

```sh
cat caelestia-wany-*.iso.*.part > caelestia-wany.iso
sha256sum -c SHA256SUMS --ignore-missing
```

`SHA256SUMS` carries the checksum of each part *and* of the reassembled image, so you can tell a bad download from a bad reassembly. The split was verified to reassemble byte-for-byte before publishing.

Write it to a USB stick (Ventoy works too):

```sh
sudo dd if=caelestia-wany.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

## Using it

Boot it and you land in caelestia's Hyprland desktop, logged in as `caelestia`. Both `caelestia` and `root` have no password. The live keyboard starts in French (AZERTY): **Caps Lock switches between French and US (QWERTY)**, Shift + Caps Lock still locks capitals.

Install it to disk with `sudo caelestia-install`. **No network is needed at any point**, because the installer copies the live system rather than downloading packages. It needs a machine booted in UEFI mode, refuses the disk the live system runs from, and writes nothing before you retype the disk path.

## Worth knowing

**No editor is included.** `Super + C` is bound to `code`, but Microsoft's VS Code build is under a commercial licence that forbids redistribution. `paru` is on the image: `paru -S visual-studio-code-bin`, or `paru -S vscodium-bin` for the free build.

**No wallpaper is included.** You get a plain background until you set one (`Super + Shift + W`, or drop images in `~/Pictures/Wallpapers`).

**Some settings are personal.** Monitor rule, avatar, keybinds. See [Making it yours](https://github.com/Wany917/caelestia-wany#making-it-yours).

**This is a snapshot.** `quickshell-git` and `qtengine-git` track a moving upstream, so an image drifts from the day it was built. Rebuild rather than treating one as evergreen.

**Reporting a bug:** include `cat /etc/caelestia-wany-release`.
