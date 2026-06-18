# Elise build / deploy / flash scripts

Helper scripts for the Elise app on the Hermes Pi 5. They wrap the manual
workflow in `docs/elise/build-deploy.md` and handle the recurring quirks: the
Pi's IP floats (DHCP), its SSH host key rotates on reflash, and the `/tmp` cross
build dir is wiped on reboot.

All scripts source `lib.sh` (shared paths + helpers) — don't run that one
directly.

## Quick reference

| Command | What it does |
|---|---|
| `./scripts/build.sh host` | x86 host build — fast "does the QML compile" check |
| `./scripts/build.sh arm` | aarch64 cross build → `/tmp/hermes-cross-build/elise` |
| `./scripts/deploy.sh` | **dev loop**: cross-build → ship to Pi → restart → journal tail |
| `./scripts/deploy.sh --no-build` | redeploy the existing binary (no rebuild) |
| `./scripts/image.sh` | rebuild the elise package + reassemble the SD image |
| `./scripts/flash.sh /dev/sdX` | flash the image to an SD card (destructive, double-confirm) |
| `./scripts/pi.sh ip` | discover + print the Pi IP |
| `./scripts/pi.sh ssh [cmd]` | shell into the Pi / run a command |
| `./scripts/pi.sh logs` | follow the hermes journal |
| `./scripts/pi.sh restart` | restart the hermes service |
| `./scripts/pi.sh fonts` | push the rootfs-overlay fonts to the running Pi |

## Typical flows

**Iterate on the app (no flash):**
```bash
./scripts/deploy.sh          # build + deploy to the running Pi
./scripts/pi.sh logs         # watch for QML errors
```
The deployed binary lives on the Pi's rootfs and **survives reboot** — a power
cycle keeps your latest deploy.

**Prepare a flashable image (everything baked in):**
```bash
./scripts/image.sh           # rebuild elise pkg + reassemble image (fonts incl.)
./scripts/flash.sh /dev/sdX  # confirm device, then dd
```
A **reflash overwrites the rootfs** with the image, so anything you only pushed
via `deploy.sh`/`pi.sh fonts` is lost unless `image.sh` was run first. Run
`image.sh` before flashing to capture the current app + fonts.

## Notes / gotchas

- **Pi IP floats** — scripts discover it by ping-sweeping the subnet and matching
  `hostname == hermes`, cached in `/tmp/hermes-pi-ip`. Override with
  `./scripts/deploy.sh <ip>`. Subnet is `192.168.0` in `lib.sh` — edit if your
  LAN differs.
- **Host key rotates on reflash** — the SSH wrappers auto `ssh-keygen -R` and
  retry, so you won't hit "REMOTE HOST IDENTIFICATION HAS CHANGED".
- **`/tmp` wiped on reboot** — `deploy.sh`/`build.sh arm` rebootstrap the cross
  dir from the Buildroot SDK (`buildroot/output/host`) automatically. The SDK
  itself only exists after one full `image.sh` run.
- **Fonts** live in `board/hermes-pi5/rootfs-overlay/usr/share/fonts/`
  (Material Symbols Rounded, JetBrains Mono) → baked into the image by
  `image.sh`; push to a running Pi with `./scripts/pi.sh fonts`.
- **`elise-dirclean`** is mandatory before an image rebuild: the package uses
  Buildroot's `local` site method, so src edits don't trigger a rebuild on
  their own. `image.sh` does this for you.
