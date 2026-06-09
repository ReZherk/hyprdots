# Hyprland Rice

My Linux desktop dotfiles (`~/.config`) — a **Hyprland** setup with a custom
**Quickshell** desktop shell and **matugen** wallpaper-based theming.

> Personal fork — originally based on
> [mkhmtolzhas/mkhmtdots](https://github.com/mkhmtolzhas/mkhmtdots),
> customized to my own setup (hardware: **Intel UHD + NVIDIA RTX**).

## Highlights

- **Custom Quickshell shell** (replaces waybar):
  - Bar on any screen edge — **top / bottom / left / right** — switchable live via
    a popup picker or hotkeys (`Super+B` to cycle, `Super+Ctrl+arrows` for a side).
  - Workspaces (vertical/horizontal to match the bar), active window, clock,
    system tray, brightness / volume / bluetooth / battery with hover tooltips
    (scroll to change volume & brightness).
  - **Dashboard** that merges out of the bar (`Super+D` or click the clock):
    media player (Mpris) with seek, calendar, CPU/RAM/temp/disk, quick toggles
    (WiFi/BT/DND), brightness/volume sliders, power buttons.
  - **Workspace overview** (`Super+T`): per-app coloured window cards you can
    **drag** between workspaces or rearrange within one (floating moves freely,
    tiled windows swap), with the real Hyprland layout updating live.
  - **Keybindings cheatsheet** (`Alt+F1`): an overlay that **auto-parses**
    `hypr/configs/keybinds.conf` into searchable, categorised cards — no manual
    list to maintain. Themed by matugen like the rest of the shell.
  - Volume / brightness **OSD**, Material 3 motion animations.
  - **Localised** (follows `$LANG`; ru/en included).
- **matugen theming** — colours generated from the wallpaper for the bar,
  kitty, rofi, mako, hyprland/hyprlock and the keyboard backlight. Changing the
  wallpaper recolours everything live (`Super+W`).
- pywal16 kept only for Firefox (pywalfox) and Discord.

## Included Configs

- `btop`
- `cava`
- `fastfetch`
- `hypr`
- `keyboard` (Lenovo Legion RGB backlight, themed from matugen)
- `kitty`
- `mako`
- `matugen`
- `nvim`
- `quickshell`
- `rofi`
- `screen`
- `wallpapers`

## Dependencies

- [Hyprland](https://github.com/hyprwm/Hyprland)
- [Quickshell](https://github.com/quickshell-mirror/quickshell)
- [Kitty](https://sw.kovidgoyal.net/kitty/)
- [Rofi](https://github.com/davatorium/rofi) (Wayland fork)
- [Mako](https://github.com/emersion/mako)
- [Matugen](https://github.com/InioX/matugen)
- [Pywal16](https://github.com/eylles/pywal16) (optional — Firefox/Discord)
- `awww` (swww fork) for wallpapers, `brightnessctl`, `playerctl`, `cliphist`
- A **JetBrainsMono Nerd Font** for the bar/terminal glyphs

## Screenshot

![Desktop Screenshot](.config/screen/image.png)

## Installation

1. Clone the repository:
   ```bash
   git clone <YOUR-REPO-URL>   # e.g. https://github.com/<your-user>/mkhmtdots
   cd mkhmtdots
   ```
2. Install the required packages:
   ```bash
   sudo pacman -S hyprland kitty rofi mako btop cava fastfetch brightnessctl \
                  playerctl cliphist ttf-jetbrains-mono-nerd
   yay -S quickshell matugen-bin python-pywal16 awww
   ```
3. Run the installer:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

### Installer Options

```bash
./install.sh --no-backup   # don't back up existing files
./install.sh --no-p10k     # don't install .p10k.zsh
./install.sh --no-theme    # don't generate matugen colours after install
./install.sh --delete      # remove files in managed dirs that aren't in this repo
```

## Notes

- **Theming is matugen.** It runs from the wallpaper scripts
  (`hypr/scripts/wallpapers/set.sh`, `set-wallpaper.sh`) on every wallpaper
  change and regenerates colours for quickshell, kitty, rofi, mako, hyprland
  and the keyboard. Quickshell reads colours from `~/.cache/quickshell-colors.json`
  live, so there's no reload/notification on wallpaper change.
- The **keyboard backlight** needs the `legion-kb-rgb` binary (Lenovo Legion).
  It is **not** shipped in this repo — drop it in `~/.config/keyboard/` or put it
  on `PATH`. Without it, `set-color-keyboard.sh` simply no-ops.
- `install.sh` installs only directories tracked in this repo and optionally
  backs up existing files to `~/.config-backups/`. It also rewrites any
  hard-coded home paths (`/home/patrick`) to the target machine's `$HOME`, so
  the configs work under a different username.
- **Hybrid GPU (Intel + NVIDIA RTX).** The NVIDIA env vars live in
  `hypr/configs/env.conf` (`LIBVA_DRIVER_NAME`, `__GLX_VENDOR_LIBRARY_NAME`).
  They only take full effect after re-logging into Hyprland. On a machine with
  different GPUs, review that file.
- Only a few sample wallpapers are committed; the rest of my collection is
  git-ignored. Drop your own images into `~/.config/wallpapers/` and theme with
  `Super+W`.
