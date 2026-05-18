# Build & Deploy

Two paths exist:

1. **Production**: Buildroot package compiled into the SD-card image.
2. **Iteration**: cross-compile elise alone with the Buildroot Qt SDK and
   deploy the binary directly to the running Pi via SSH/SCP.

The dev loop uses path 2.

## Targets at a glance

| Target           | Path                                                    |
|------------------|---------------------------------------------------------|
| Pi 5 (running)   | `192.168.0.101`, user `root`                            |
| Cross build dir  | `/tmp/hermes-cross-build` (host, Linux x86_64)          |
| On-device binary | `/usr/bin/elise`                                        |
| systemd service  | `hermes.service` (cage + elise)                         |
| Music daemon     | `hermes-music.service` (Python FastAPI on 127.0.0.1:8765) |

## Cross-compile (incremental)

The cross build dir was set up once with the Buildroot toolchain. After that,
every iteration is a one-liner:

```bash
cd /tmp/hermes-cross-build
cmake --build . -- -j$(nproc)
```

If you need to recreate the cross build dir from scratch (toolchain change,
clean rebuild, etc.):

```bash
TOOLCHAIN=/path/to/buildroot/output/host
PREFIX=$TOOLCHAIN/aarch64-buildroot-linux-gnu/sysroot

mkdir -p /tmp/hermes-cross-build && cd /tmp/hermes-cross-build

$TOOLCHAIN/bin/qt-cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DQT_CHAINLOAD_TOOLCHAIN_FILE=$TOOLCHAIN/share/buildroot/toolchainfile.cmake \
  -DQT_ADDITIONAL_PACKAGES_PREFIX_PATH=$PREFIX/usr \
  /home/mirage/Projects/hermes/src/elise

cmake --build . -- -j$(nproc)
```

Build output: `/tmp/hermes-cross-build/elise` (aarch64 ELF).

## Deploy to Pi

The Pi runs a stripped image without sftp-server, so use SCP's legacy
protocol (`-O`):

```bash
ssh root@192.168.0.101 systemctl stop hermes
scp -O /tmp/hermes-cross-build/elise root@192.168.0.101:/usr/bin/elise
ssh root@192.168.0.101 systemctl start hermes
```

`systemctl stop` first because the running binary is held open by the active
process (`Text file busy` otherwise).

Quick one-liner for the inner loop:

```bash
ssh root@192.168.0.101 'systemctl stop hermes' \
  && cd /tmp/hermes-cross-build \
  && cmake --build . -- -j$(nproc) \
  && scp -O elise root@192.168.0.101:/usr/bin/elise \
  && ssh root@192.168.0.101 'systemctl start hermes'
```

## Watching logs

QML errors and `console.log` output go to the systemd journal, NOT to
stderr-over-SSH. Always check the journal:

```bash
ssh root@192.168.0.101 journalctl -u hermes -n 30 --no-pager
```

Tail in real time:

```bash
ssh root@192.168.0.101 journalctl -u hermes -f
```

Filter QML lines only:

```bash
ssh root@192.168.0.101 'journalctl -u hermes -n 50 --no-pager | grep -E "qml:|error"'
```

## Music daemon (hermes-music)

Deployed as Python source (no PyInstaller — Buildroot lacks `ldd`):

```
/usr/share/hermes-music/main.py    # FastAPI app
/etc/systemd/system/hermes-music.service
```

Service file:

```ini
[Service]
ExecStart=/usr/bin/python3 /usr/share/hermes-music/main.py
WorkingDirectory=/usr/share/hermes-music
```

To redeploy the daemon source after edits:

```bash
scp -O -r src/hermes-music/* root@192.168.0.101:/usr/share/hermes-music/
ssh root@192.168.0.101 systemctl restart hermes-music
```

## Buildroot full-image rebuild

When changes touch C++ controllers, dependencies, or the package manifest:

```bash
cd buildroot
make hermes_pi5_defconfig
make
```

Output image: `buildroot/output/images/sdcard.img`.

The `elise` package is at `package/elise/`. Source is pulled from
`$(BR2_EXTERNAL_HERMES_PATH)/src/elise` via `local` site method, so
Buildroot copies the whole directory at build time. `src/elise/build/` and
`src/elise/docs/` are not present in the source tree any more (build dir is
git-ignored, docs were moved to top-level `docs/elise/`), so nothing
extraneous gets copied into the image.

## On-device file layout

```
/usr/bin/elise                                         # the binary
/usr/share/hermes-music/                               # Python daemon source
/etc/systemd/system/hermes.service                     # cage + elise
/etc/systemd/system/hermes-music.service               # daemon
/etc/systemd/system/wpa_supplicant@wlan0.service       # Wi-Fi (default)
/etc/wpa_supplicant/wpa_supplicant-wlan0.conf          # Wi-Fi config skeleton
```

## Common pitfalls

- **`scp` fails with `subsystem request failed`** — use `scp -O` (legacy SCP
  protocol). The Pi's BusyBox sshd has no sftp-server.
- **Pi `tar` cannot decompress `.tar.gz`** — its BusyBox `tar` lacks `-z`.
  Use uncompressed `tar cf` on the host and `tar xf` on the Pi.
- **`Text file busy` on `scp`** — stop the service first.
- **App exits status 1, no message** — the binary printed a QML load error
  to the journal, not stderr. Run `journalctl -u hermes -n 30`.
- **Touchscreen not working after a kernel update** — confirm USB
  enumeration with `lsusb` (`0eef:0005`) and event delivery with
  `cat /dev/input/event0 | xxd` while tapping (raw evdev still works even
  when cage holds the seat).

## Useful one-shots

Confirm service health:

```bash
ssh root@192.168.0.101 'systemctl is-active hermes hermes-music'
```

Fast iteration (build + deploy + log tail):

```bash
ssh root@192.168.0.101 'systemctl stop hermes' \
  && cmake --build /tmp/hermes-cross-build -- -j$(nproc) \
  && scp -O /tmp/hermes-cross-build/elise root@192.168.0.101:/usr/bin/elise \
  && ssh root@192.168.0.101 'systemctl start hermes && sleep 2 && journalctl -u hermes -n 20 --no-pager'
```

Get a Wayland touch event trace (stops `hermes` first; `cage` must release
the seat before libinput debug can read it):

```bash
ssh root@192.168.0.101 'systemctl stop hermes; libinput debug-events --verbose; systemctl start hermes'
```
