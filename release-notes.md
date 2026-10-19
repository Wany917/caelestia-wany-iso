An Arch Linux ISO that boots straight into **[caelestia](https://github.com/caelestia-dots/caelestia)** by [@soramanew](https://github.com/soramanew) and the caelestia-dots team, pre-configured with the [caelestia-wany](https://github.com/Wany917/caelestia-wany) overlay.

**All credit for the desktop goes to caelestia.** This image contains no desktop of its own: it packages caelestia's work into something installable. If you like what you see when it boots, that is their work. Please star and support the original project.

## New since v2026.10.16

- **caelestia-shell 2.5.0** (was 1.6.2). Settings move to the new Nexus app (`Super + Shift + T`, or `>settings` in the launcher), and the media tab of the dashboard shows synced lyrics on its own.
- **The shell font is included.** caelestia 2.x is designed around Google Sans Flex but does not install it, so you would get a fallback font. It is on the image now.
- **No more held-back packages.** v2026.10.16 kept `caelestia-shell`, `libcava` and `qt6-m3shapes-git` from updating, because `paru` could not move the shell from 1.x to 2.x. With 2.x on the image, the installed system updates them like everything else. The check that runs after every update stays, and still tells you what to run if the shell would not start.
- **Choose your keyboard at the boot menu.** The default entry is US (QWERTY), the next one French (AZERTY), and Caps Lock switches to the other layout in the live session. The installer suggests the layout you booted with. Thanks to @sharicov for asking (#2).
- **The live system no longer waits for a network clock.** Without a connection, a time sync service waited forever: the console showed "A start job is running for Wait Until Kernel Time Synchronized", and some services never started, on the live and on installed systems alike. Reported by @xrompf (#1).
- **One desktop shell per session.** Every session used to start two copies of the caelestia shell on top of each other.
- Rebuilt against current Arch packages.

**Installed from v2026.10.16?** Keep the hold in `/etc/pacman.conf` and that system keeps working. Moving it to 2.x by hand also means replacing patched shell files and the shell config, so reinstalling from this image is the simpler path (back up your home first).

**Still on v2026.08.16?** It does not start on most real machines (#1, #2). Use this release.

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

Boot it and you land in caelestia's Hyprland desktop, logged in as `caelestia`. Both `caelestia` and `root` have no password. Pick the keyboard at the boot menu (US by default, or French); **Caps Lock switches to the other layout**, and Shift + Caps Lock still locks capitals.

Install it to disk with `sudo caelestia-install`. **No network is needed at any point**, because the installer copies the live system rather than downloading packages. It needs a machine booted in UEFI mode, refuses the disk the live system runs from, and writes nothing before you retype the disk path.

## Worth knowing

**No editor is included.** `Super + C` is bound to `code`, but Microsoft's VS Code build is under a commercial licence that forbids redistribution. `paru` is on the image: `paru -S visual-studio-code-bin`, or `paru -S vscodium-bin` for the free build.

**No wallpaper is included.** You get a plain background until you set one (`Super + Shift + W`, or drop images in `~/Pictures/Wallpapers`).

**Some settings are personal.** Monitor rule, avatar, keybinds. See [Making it yours](https://github.com/Wany917/caelestia-wany#making-it-yours).

**This is a snapshot.** `quickshell-git` and `qtengine-git` track a moving upstream, so an image drifts from the day it was built. Rebuild rather than treating one as evergreen.

**Reporting a bug:** include `cat /etc/caelestia-wany-release`.
