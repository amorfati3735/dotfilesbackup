<div align="center">

# ⚡ dotfiles

**My EndeavourOS rice — Hyprland, Quickshell (illogical-impulse), and everything that makes it tick.**
Snapshotted nightly by a systemd timer, because restoring a working desktop from memory is not a hobby.

[![EndeavourOS](https://img.shields.io/badge/EndeavourOS-Arch-7C3AED?style=for-the-badge&logo=archlinux&logoColor=white)](https://endeavouros.com/)
[![Hyprland](https://img.shields.io/badge/Hyprland-Wayland-00B4D8?style=for-the-badge&logo=wayland&logoColor=white)](https://hyprland.org/)
[![Quickshell](https://img.shields.io/badge/Quickshell-QML-3DDC97?style=for-the-badge&logo=qt&logoColor=white)](https://quickshell.org/)
[![Backup](https://img.shields.io/badge/backup-systemd%20timer-FF6B6B?style=for-the-badge&logo=systemd&logoColor=white)](#-how-it-works)

![Last commit](https://img.shields.io/github/last-commit/amorfati3735/dotfilesbackup?style=flat-square&color=7C3AED)
![Repo size](https://img.shields.io/github/repo-size/amorfati3735/dotfilesbackup?style=flat-square&color=00B4D8)
![Top language](https://img.shields.io/github/languages/top/amorfati3735/dotfilesbackup?style=flat-square&color=3DDC97)

</div>

---

## 🎹 Stack

| | Component |
|---|---|
| **WM** | Hyprland (Lua config manager — not hyprlang) |
| **Shell** | Quickshell / illogical-impulse (`qs -c ii`) |
| **Terminal** | kitty · foot |
| **Launcher** | rofi · fuzzel · the `Super` overview |
| **Bar & OSD** | Quickshell bar, custom widgets |
| **Theming** | matugen (Material You from wallpaper), GTK 3/4 |
| **Shell** | fish · bash (dotfiles only) |
| **Extras** | cava, btop, mpv, fastfetch, micro |

## 📦 What's in here

| Path | Contents |
|---|---|
| `hypr/` | Hyprland: `custom/` keybinds + scripts, `hyprland/` modules, lock, idle |
| `quickshell/` | Quickshell rice: modules, services, widgets, translations |
| `kitty/`, `foot/` | Terminal configs |
| `fish/` | Fish shell config and completions |
| `rofi/`, `fuzzel/` | Launcher themes |
| `matugen/` | Material You color templates |
| `btop/`, `mpv/`, `cava/`, `fastfetch/` | App configs |
| `gtk-3.0/`, `gtk-4.0/` | GTK theming |
| `local-bin/` | Small utility scripts |
| `systemd-user/` | User services and timers |
| `pkglist.txt`, `aur-pkglist.txt` | Explicit + AUR package lists |
| `enabled-services.txt` | Enabled user units |
| `etc/` | Readable copies of a few system configs |
| `bashrc`, `bash_profile`, `profile`, `gitconfig` | Home dotfiles |

## 🔁 How it works

```
dotfiles-backup.timer        (daily, 14:05)
        │
        ▼
dotfiles-backup.sh           rsync ~/.config subset + scripts + package lists
        │
        ▼
~/backups/dotfiles           git add -A && commit && push
        │
        ▼
github.com/amorfati3735/dotfilesbackup
```

- **Automatic** — `systemctl --user list-timers | grep backup`
- **Manual** — run `dotfiles-backup.sh` for a rofi prompt to name the commit
- **Restore** — clone this repo somewhere and copy what you need back into `~/.config`

Secrets are deliberately not tracked: `fish/fish_variables`, `dconf-dump.ini`,
and anything under `~/.env_secrets` stay out of the repo.

## 🧩 Restoring on a new machine

```bash
# 1. The rice itself (upstream base)
git clone https://github.com/end-4/dots-hyprland && cd dots-hyprland && ./setup install

# 2. My overrides
git clone https://github.com/amorfati3735/quickshell-dots ~/.config/quickshell/ii
git clone https://github.com/amorfati3735/hypr-dots     ~/.config/hypr

# 3. Packages this repo tracked
paru -S --needed - < pkglist.txt
paru -S --needed - < aur-pkglist.txt
```

## 📊 Stats

<div align="center">

![Stats](https://github-readme-stats.vercel.app/api?username=amorfati3735&show_icons=true&hide_border=true&bg_color=0D1117&title_color=7C3AED&icon_color=00B4D8&text_color=C9D1D9)
![Streak](https://streak-stats.demolab.com?user=amorfati3735&hide_border=true&background=0D1117&stroke=7C3AED&ring=3DDC97&fire=FF6B6B&currStreakLabel=C9D1D9)

</div>

## 🙏 Credits

Built on top of [**end-4/dots-hyprland**](https://github.com/end-4/dots-hyprland) —
the illogical-impulse shell, its widgets and their installer did the heavy lifting. Go star it.

<div align="center">

<sub>Snapshots are generated automatically. If you're here for a copy-paste rice, take whatever helps. 🌊</sub>

</div>
