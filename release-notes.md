An Arch Linux ISO that boots straight into **[caelestia](https://github.com/caelestia-dots/caelestia)** by [@soramanew](https://github.com/soramanew) and the caelestia-dots team, pre-configured with the [caelestia-wany](https://github.com/Wany917/caelestia-wany) overlay.

**All credit for the desktop goes to caelestia.** This image contains no desktop of its own: it packages caelestia's work into something installable. If you like what you see when it boots, that is their work. Please star and support the original project.

## New since v2026.10.19

- **Sound works.** The image shipped PipeWire without its audio modules: no sound card showed up (`wpctl status` listed only the webcam), browsers and Discord had no sound, and the volume fell back to 0. PipeWire's ALSA, PulseAudio and Bluetooth audio support are on the image now, with `pavucontrol` behind the shell's audio settings button. Thanks to @ahmadprogrammer111 for the report (#3).
- **Bluetooth works.** BlueZ was missing, so the Bluetooth toggle switched itself back off. It is included and its service enabled, on the live and on installed systems.
- **A file manager.** `Super + E` and the shell open Thunar, which was not on the image. Trash, USB sticks and thumbnails work in it.
- **Password prompts for graphical apps and a keyring.** The polkit agent and GNOME Keyring that the session starts were missing.
- **The live session no longer locks after 3 minutes** and asks for a password the account does not have.
- The launcher no longer lists the Avahi SSH and VNC browsers.
- Rebuilt against current Arch packages.

**Installed from v2026.10.19 or older?** You can get sound and Bluetooth without reinstalling, with a network connection:

```sh
paru -S --needed pipewire-audio pipewire-alsa pipewire-pulse pavucontrol bluez bluez-utils thunar gvfs tumbler polkit-gnome gnome-keyring
sudo systemctl enable --now bluetooth
```

Then log out and back in.

## Getting the ISO

GitHub caps release files at 2 GiB and the image is larger, so it is split. Download every `.part` file plus `SHA256SUMS`, then reassemble:

```sh
cat caelestia-wany-*.iso.*.part > caelestia-wany.iso
sha256sum -c SHA256SUMS --ignore-missing
```

`SHA256SUMS` carries the checksum of each part *and* of the reassembled image, so you can tell a bad download from a bad reassembly. The split was verified to reassemble byte-for-byte before publishing.

Write it to a USB stick (Ventoy works too). Turn Secure Boot off first: the image is not signed for it, like Arch's own ISO.

```sh
sudo dd if=caelestia-wany.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

## Using it

Boot it and you land in caelestia's Hyprland desktop, logged in as `caelestia`. Both `caelestia` and `root` have no password. Pick the keyboard at the boot menu (US by default, or French); **Caps Lock switches to the other layout**, and Shift + Caps Lock still locks capitals.

Install it to disk with `sudo caelestia-install`. **No network is needed at any point**, because the installer copies the live system rather than downloading packages. It needs a machine booted in UEFI mode, refuses the disk the live system runs from, and writes nothing before you retype the disk path.

## Worth knowing

**No editor is included.** `Super + C` is bound to `code`, but Microsoft's VS Code build is under a commercial licence that forbids redistribution. `paru` is on the image: `paru -S visual-studio-code-bin`, or `paru -S vscodium-bin` for the free build.

**One wallpaper is included**, the default that ships with caelestia. Drop your own images in `~/Pictures/Wallpapers`, then `Super + Shift + W` switches to a random one.

**Some settings are personal.** Monitor rule, avatar, keybinds. See [Making it yours](https://github.com/Wany917/caelestia-wany#making-it-yours).

**This is a snapshot.** `quickshell-git` and `qtengine-git` track a moving upstream, so an image drifts from the day it was built. Rebuild rather than treating one as evergreen.

**Reporting a bug:** include `cat /etc/caelestia-wany-release`.
