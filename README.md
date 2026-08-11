# ubuntu

Personal dotfiles and scripts for a home Linux setup — shell aliases/functions,
a `.bashrc`, and a MagicMirror kiosk installer.

## Files

### `.bashrc`

Standard Debian-derived interactive-shell config (history settings, prompt,
`ls`/`grep` color aliases, completion). It sources `~/.bash_aliases` and
`~/.bash_functions` if present, loads `nvm`, and sets a custom colored prompt
that shows your public IP (`get_ip`) alongside the current directory.

### `.bash_aliases`

Shortcuts and helper functions for managing this machine's services.

**Aliases:**

| Alias | What it does |
|---|---|
| `mm` / `mmmodule` / `mmconfig` / `checkconfig` | Jump to/edit/validate the MagicMirror install |
| `plex_start` / `plex_stop` | Start/stop the Plex docker stack |
| `pihole_start` / `pihole_stop` | Start/stop the Pi-hole docker stack |
| `aptup` | `apt update && apt upgrade -y` |
| `makealias` / `updatealias` | Edit / reload `~/.bash_aliases` |
| `battery` | Show battery state and charge percentage |
| `seemonitor` / `checkmonitor` / `checkdisplay` | Inspect connected displays |
| `entervenv` | Activate the `/srv/schedule` Python virtualenv |
| `checkvpn` | Check the qBittorrent container's VPN-exposed IP |
| `dockerports` / `dockerlist` / `dc` | List running containers and their ports |
| `backupnow` / `restorenow` | Create/list Snapper snapshots |
| `mntfile` / `mnt` / `tbdrive` / `tbplex` | Edit fstab, mount, and jump to mounted drives |
| `cleanup` | Clean the zypper package cache and vacuum old journal logs |
| `updatelog` | Tail recent `packagekit` update activity from the journal |

**Functions** (each supports `-h`/`--help` for usage):

| Function | What it does |
|---|---|
| `gitone <path>...` | `git add` the given path(s), commit with an auto message, and push |
| `dockerup <stack>` | `cd $DOCKER_BASE/<stack> && docker compose up -d` |
| `dockerdown <stack>` | `cd $DOCKER_BASE/<stack> && docker compose down` |
| `dockerlogs <stack>` | `cd $DOCKER_BASE/<stack> && docker compose logs -f` |
| `dockerupdate <stack>` | Pull latest images and recreate the stack |
| `dockershell <name>` | Exec a shell into the first running container matching `<name>` |
| `dockercomp <stack>` | Open a stack's `docker-compose.yml` in nano (sudo) |
| `email <file> [subject] [recipient]` | Email a file's contents via Gmail SMTP |

`$DOCKER_BASE` defaults to `~/docker`.

### `bash_functions`

Numbered file-navigation helpers plus lightweight git shortcuts, meant to be
sourced from `.bashrc`. Every command below (except `lsn`) operates on the
numbers printed by the last `lsn` — re-run `lsn` after the working directory
changes. All support `-h`/`--help` for usage.

| Function | What it does |
|---|---|
| `lsn` | List everything in the current directory (hidden files too), numbered |
| `cdn <n>` | `cd` into item `<n>` (auto re-lists) |
| `nanon <n>...` | Open item(s) `<n>` in `nano` (uses `sudo` only when needed) |
| `catn <n>...` | Print item(s) `<n>` |
| `sour <n>...` | Print the resolved path(s) of item(s) `<n>` (for `$(sour N)`) |
| `mvn <n>... <dest>` | Move item(s) `<n>` into/to `<dest>` (auto re-lists) |
| `cpn <n>... <dest>` | Copy item(s) `<n>` into/to `<dest>` (auto re-lists) |
| `rmx <n>...` | Remove item(s) `<n>`, with a confirmation prompt (auto re-lists) |
| `pullgit [<n>\|<name>]` | Clone/update a `yelrambob/<name>` repo, keeping untracked files (no arg = update the current directory) |
| `pushgit [<n>\|<dir>] [message]` | Stage, commit, and push a repo; warns on and excludes files that look like secrets (e.g. `credentials.json`, `.env`, `*.pem`) |

### `mm_kiosk_install.sh`

Installer for a Raspberry Pi (Pi OS Lite) that turns it into a MagicMirror
kiosk display. Run with `-h`/`--help` to see a summary without making changes.
It installs X11/openbox/Chromium, enables console auto-login, writes a kiosk
launcher script and `.xinitrc`/`.bash_profile` to auto-start Chromium in
kiosk mode against a MagicMirror server, disables screen blanking, sets
`gpu_mem`, enables the `watchdog` service, then reboots.

Run it with:

```sh
curl -fsSL https://raw.githubusercontent.com/yelrambob/ubuntu/main/mm_kiosk_install.sh | bash
```

See the `installation steps` file for the manual, step-by-step equivalent of
what this script automates.

### `installation steps`

Plain-text notes documenting the manual steps for setting up the MagicMirror
kiosk (the same steps `mm_kiosk_install.sh` automates), for reference or
troubleshooting.

### `.config.js`

MagicMirror module/layout configuration.
