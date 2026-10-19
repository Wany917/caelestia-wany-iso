# caelestia-wany-iso

> An Arch Linux ISO that ships **[caelestia](https://github.com/caelestia-dots/caelestia)** by [@soramanew](https://github.com/soramanew) and the [caelestia-dots](https://github.com/caelestia-dots) team, pre-configured with my personal overlay [caelestia-wany](https://github.com/Wany917/caelestia-wany).
>
> **All credit for the desktop goes to caelestia.** This repository contains no desktop of its own: it is build tooling that packages caelestia's work into an installable image. It is not a distribution, not a fork of Arch, and not a reinvention of anything. If you like what you see when it boots, that is caelestia. Please star and support the original project.

## What it does

Boot the ISO and you land straight in caelestia's Hyprland desktop. Install it to disk and the same desktop comes back after you log in, configured, with no network needed.

The point is to skip the "install Arch, then spend an evening reapplying dotfiles" step on a new machine.

## Getting the ISO

Releases are on the [releases page](https://github.com/Wany917/caelestia-wany-iso/releases). GitHub caps release files at 2 GiB and the image is larger, so it is split. Download every `.part` file plus `SHA256SUMS`, then reassemble:

```sh
cat caelestia-wany-*.iso.*.part > caelestia-wany.iso
sha256sum -c SHA256SUMS --ignore-missing
```

Write it to a USB stick (this erases the stick):

```sh
sudo dd if=caelestia-wany.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Ventoy works too.

## The live session

The desktop starts on its own, logged in as `caelestia`. Nothing to type.

| Account | Password | Used for |
|---|---|---|
| `caelestia` | none | the desktop, `sudo` without a password |
| `root` | none | the console login on TTY2 to TTY6, if you need it |

**Keyboard.** Pick it at the boot menu: the default entry is US (QWERTY), the next one is French (AZERTY). In the live session, **Caps Lock switches to the other layout**, and Shift + Caps Lock still locks capitals. The consoles on TTY2 and up follow the boot menu choice.

The installer asks for your layout and suggests the one you booted with, so the installed system uses yours.

## Installing

Open a terminal (`Super + T`) and run:

```sh
sudo caelestia-install
```

It asks for a hostname, a username, a timezone, a locale, a keyboard layout and a password, then for the disk to erase. Nothing is written before you retype the disk path on the summary screen. It needs a machine booted in **UEFI** mode and refuses to run otherwise rather than leave you with an unbootable system. It also refuses the disk the live system runs from.

No network is needed at any point: the installer copies the live system instead of downloading packages. After a reboot, a login screen asks for your password and the desktop opens with your keyboard layout.

## Updating

Update with `paru`, like any Arch system. After each update, a check runs: if the shell would not start (typically `quickshell-git` after a Qt update, which needs a rebuild), you get a yellow warning at the end of the update with the exact command to run, usually `paru -S --rebuild quickshell-git`. Run `caelestia-health` any time to check again.

**Installed from v2026.10.16?** That image shipped `caelestia-shell` 1.x and holds it back with `IgnorePkg` in `/etc/pacman.conf`, because `paru` cannot move 1.x to 2.x on its own: the desktop would come back black. Leave the hold in place and the system keeps working as it is. Moving it to 2.x by hand also means replacing patched shell files and the shell config, so reinstalling from a newer image is the simpler path. Back up your home first, the installer erases the disk.

## Troubleshooting

**The desktop does not start, or you land on a login prompt.** Switch to another console with `Ctrl + Alt + F2`, log in as `root` (no password) and look at:

```sh
journalctl -b -u greetd -u caelestia-live-setup
```

**Using v2026.08.16?** That release fails on most real machines: archiso copies the image to RAM at boot, and the live setup did not run in that case ([#2](https://github.com/Wany917/caelestia-wany-iso/issues/2)). Newer releases fix it. With that release, highlight the first boot entry, press `e`, add ` copytoram=n` at the end of the kernel line and boot it (Enter, or Ctrl+X in GRUB, which is what Ventoy shows).

**Reporting a bug.** Include your hardware, how you wrote the USB stick, and the output of `cat /etc/caelestia-wany-release`, which records what the image was built from.

## How it works

Three moving parts, because pacstrap cannot read the AUR and a dotfiles installer expects a running desktop.

**1. A local pacman repository.** caelestia needs AUR packages (`caelestia-shell`, `caelestia-cli`, `quickshell-git`, `qtengine-git`, `app2unit` and a few transitive dependencies), plus `paru`, the browser bound to `Super + W` and the shell's default font, Google Sans Flex, which `caelestia-shell` does not declare. `pacstrap` cannot read the AUR, so they are taken pre-built from the build machine and served from a repository at build time.

**2. An archiso profile.** The standard `releng` profile, plus that repository, the package set, and a live user started by greetd. Hyprland refuses to run as root, which is why the live session has a real user.

**3. The rice, applied without a network.** The dotfiles are embedded from a git commit of caelestia-wany. At boot, a service links them into the live user's home before greetd opens the session. The installer copies the whole live system to disk, creates your user, and applies the same dotfiles to your home from inside the new system. `install.fish` is not used, because it installs packages and needs a running Hyprland.

## Building

Needs an up-to-date Arch host with `archiso` and `devtools`, the AUR packages installed through `paru`, and about 20 GB of free space.

```sh
paru -S --needed archiso devtools
git clone git@github.com:Wany917/caelestia-wany-iso.git
cd caelestia-wany-iso
./build.fish
```

The build stops early, with the command to run, when:

- the host has pending updates. The image gets today's official packages, so the AUR packages must have been built against the same libraries.
- an AUR package is missing from the `paru`/`pacman` caches. Nothing is compiled behind your back: `quickshell-git` alone takes the better part of an hour.
- a package built against Qt's private API (`quickshell-git`) was compiled for another Qt version. It would crash on boot.

Packages whose AUR version no longer builds are kept in `pkgbuilds/`, with sources pinned to a commit. Build each one with `makepkg -f` in its folder, then install the result with `paru -U`.

The rice comes from `~/.local/share/caelestia` at the `main` branch. Change it with `scripts/make-profile.fish --rice <path> --rice-ref <ref>`. Uncommitted changes are never embedded.

## Testing it

Everything runs in a throwaway VM under `vm/`. Nothing touches the host.

```sh
./scripts/test-vm.fish --live               # does the desktop come up?
./scripts/test-vm.fish --install            # ISO + blank disk, run caelestia-install inside
./scripts/test-vm.fish --disk --offline     # boot the installed system with no network
```

The ISO is attached as a USB stick, not a CD. That matters: from a USB stick with enough RAM, archiso copies the image to memory and unmounts the medium, like on real hardware. From a CD it never does, which is how the bug in v2026.08.16 got through. `--cdrom` is still available.

The last test is the one that proves the offline claim. The default display is VNC on `localhost:5901`. Install `qemu-ui-gtk` and pass `--display gtk` for a native window, and `qemu-hw-display-virtio-vga` for a usable framerate.

## No editor on the image

`Super + C` is bound to `code`, but no editor ships with the ISO. Microsoft's VS Code build is under a commercial licence that does not allow redistribution: the AUR package downloads it from Microsoft at build time rather than hosting it, for exactly that reason. Bundling it into a public image would not be legitimate.

`paru` is on the image, so pick one after installing:

```sh
# Microsoft's build: MS marketplace, MS telemetry
paru -S visual-studio-code-bin

# VSCodium: same editor, free build, no MS telemetry, Open VSX marketplace
paru -S vscodium-bin
```

VSCodium's binary is `codium`: set `editor = "codium"` in `~/.local/share/caelestia/custom/overrides/hypr-vars.lua` if you go that way.

## Caveats

**The image is a snapshot.** `quickshell-git` and `qtengine-git` are VCS packages: they track a moving upstream. An image built today ships today's commit and drifts from then on. Rebuild periodically rather than treating an image as evergreen.

**It carries some of my setup.** A monitor rule, the avatar, the session GIFs. See "Making it yours" in the [caelestia-wany README](https://github.com/Wany917/caelestia-wany#making-it-yours). Machine settings that the installer writes live in `~/.config/caelestia/hypr-local.lua`.

**One wallpaper is included**, the default that ships with caelestia. Drop your own images in `~/Pictures/Wallpapers`, then `Super + Shift + W` switches to a random one.

**`paru`, not `paru-bin`.** The `-bin` variant installs under the package name `paru-bin` and only *provides* `paru`. `install.fish` checks `pacman -Q paru`, which matches on name, not provides, so with `paru-bin` it would try to bootstrap paru from the AUR and the offline promise would break.

## Credits

The desktop, the shell and the entire design are **[caelestia](https://github.com/caelestia-dots)** by soramanew and contributors. caelestia does not declare a license, so this repository follows upstream and claims no ownership over caelestia's work. Arch Linux and `archiso` are the work of the [Arch Linux](https://archlinux.org) project. Please support the original projects first. 💙
