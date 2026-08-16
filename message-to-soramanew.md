# Message à poster — Discussions de caelestia-dots/shell

Catégorie suggérée : **General** (ou **Show and tell** si elle existe).

Titre :

```
Built a personal overlay + an installable ISO on top of caelestia — is this okay with you?
```

Corps :

---

Hi @soramanew,

First: thank you for caelestia. It is the reason my desktop looks and works the way it does, and I have learned a lot reading how the shell is put together.

I have built two things on top of it and I would rather ask you about them than assume it is fine.

**1. A personal overlay fork of the dots** — [caelestia-wany](https://github.com/Wany917/caelestia-wany). It is your repo with my own layer in a `custom/` folder: my keybinds, a Cheatsheet dashboard tab, an animated avatar patch, synced lyrics in the media tab, and a modular installer. I track your `main` as `upstream` and keep my changes isolated so they stay easy to merge. The README credits caelestia at the top and states plainly that this is an overlay, not an original project.

**2. An Arch ISO that ships it pre-configured** — [caelestia-wany-iso](https://github.com/Wany917/caelestia-wany-iso). It boots straight into caelestia and installs to disk without needing a network. I built it so I could set up a new machine without spending an evening reapplying dotfiles. It contains no desktop of its own: it packages your work into something installable.

**What I am asking**

- Are you comfortable with these existing? If not, I will take them down, no argument.
- Does the naming work for you? "caelestia-wany" and "caelestia-wany-iso" were meant to read as clearly derivative rather than as competing projects, but if you would prefer something that does not lead with your project's name, tell me what you would like and I will rename them.
- Is there anything in how I credit caelestia that you would word differently? I would rather match what you actually want than guess.

**One practical question**

The dots repo does not declare a licence. That leaves people who want to build on it — or in my case redistribute it inside an image — without a clear answer on what is allowed. I have proceeded on the assumption that a public dotfiles project is meant to be used and shared, and I credit you everywhere, but I am aware that is an assumption and not permission.

If you ever add a licence, it would settle that for everyone, not just me. And if the answer for my ISO specifically is "please don't redistribute it", that is completely fine — I will keep it private.

**Contributing back**

Some of what I built might be useful upstream rather than living in my fork. If any of it interests you, I am happy to clean it up and open a PR instead of keeping it on the side.

Thanks again, genuinely.

---

## Notes pour toi (à ne pas poster)

- Le dépôt du rice est **privé**, mais une invitation en lecture lui a été envoyée (2026-08-16). Il pourra ouvrir le premier lien **une fois qu'il l'aura acceptée** — pas avant. Si tu veux éviter cette dépendance, passe le rice en public avant de poster.
- L'ISO ne contient PAS VS Code (licence Microsoft non redistribuable), donc rien de problématique de ce côté si la question vient.
- S'il demande un renommage, le coût est faible : deux `gh repo rename`, les remotes à mettre à jour, et les liens dans les deux README.
