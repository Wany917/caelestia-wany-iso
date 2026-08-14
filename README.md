# caelestia-wany-iso

> An Arch Linux ISO that ships **[caelestia](https://github.com/caelestia-dots/caelestia)** by [@soramanew](https://github.com/soramanew) and the [caelestia-dots](https://github.com/caelestia-dots) team, pre-configured with my personal overlay [caelestia-wany](https://github.com/Wany917/caelestia-wany).
>
> **All credit for the desktop goes to caelestia.** This repository contains no desktop of its own: it is build tooling that packages caelestia's work into an installable image. It is not a distribution, not a fork of Arch, and not a reinvention of anything. If you like what you see when it boots, that is caelestia — please star and support the original project.

## What it does

Boot the ISO and you land straight in caelestia's Hyprland desktop. Install it to disk and the same desktop comes back on first login, configured, with no network needed.

The point is to skip the "install Arch, then spend an evening reapplying dotfiles" step on a new machine.

## How it works

Three moving parts, because a dotfiles installer and an OS installer do not run in the same world.

**1. A local pacman repository.** caelestia needs six AUR packages (`caelestia-cli`, `caelestia-shell`, `quickshell-git`, `qtengine-git`, `app2unit`, `paru`) and `pacstrap` cannot read the AUR. They are pre-built and served from a repository baked into the image, which is also what makes an offline install possible.

**2. An archiso profile.** Standard `releng` base, plus the local repository, plus the package set and the autologin session that brings the live environment up in caelestia.

**3. A first-login hook.** `install.fish` calls `hyprctl` and starts the shell, so it needs a live Hyprland to talk to — it cannot run inside the installer's chroot. The installer clones the dotfiles into the new user's home and leaves a trigger; the rice finishes applying itself the first time you log in.

## Building

Needs `archiso` and `devtools`, an Arch host, and roughly 20 GB of free space.

```sh
sudo pacman -S --needed archiso devtools
git clone git@github.com:Wany917/caelestia-wany-iso.git
cd caelestia-wany-iso
./build.fish
```

The AUR packages come from the build machine's own `paru`/`pacman` caches, so the image ships the exact binaries that were tested there. Anything missing stops the build with the command to run — nothing is compiled behind your back, because `quickshell-git` alone takes the better part of an hour.

## Testing it

Everything runs in a throwaway VM under `vm/`. Nothing touches the host.

```sh
./scripts/test-vm.fish --live               # does the desktop come up?
./scripts/test-vm.fish --install            # ISO + blank disk, run caelestia-install inside
./scripts/test-vm.fish --disk --offline     # boot the installed system with no network
```

That last one is the test that matters: if the desktop comes back with the network cut, the offline claim holds. `qemu-base` has no GUI backend, so the default is VNC on `localhost:5901` — connect with any viewer. Install `qemu-ui-gtk` and pass `--display gtk` if you'd rather have a native window.

`caelestia-install` wipes the disk you point it at. It refuses to run outside the live session, refuses on a BIOS-booted machine rather than leaving you unbootable, refuses the disk carrying the live medium, and makes you retype the device path before touching anything.

## Caveats

**The image is a snapshot.** `quickshell-git` and `qtengine-git` are VCS packages: they track a moving upstream. An ISO built today ships today's commit and drifts from then on. Rebuild periodically rather than treating an image as evergreen.

**It hardcodes some of my setup.** Monitor layout, avatar, session GIFs. See "Making it yours" in the [caelestia-wany README](https://github.com/Wany917/caelestia-wany#making-it-yours).

**`paru`, not `paru-bin`.** The `-bin` variant installs under the package name `paru-bin` and only *provides* `paru`. `install.fish` checks `pacman -Q paru`, which matches on name, not provides — so with `paru-bin` it would try to bootstrap paru from the AUR at first boot and the offline promise would break.

## Credits

The desktop, the shell and the entire design are **[caelestia](https://github.com/caelestia-dots)** by soramanew and contributors. caelestia does not declare a license, so this repository follows upstream and claims no ownership over caelestia's work. Arch Linux and `archiso` are the work of the [Arch Linux](https://archlinux.org) project. Please support the original projects first. 💙
