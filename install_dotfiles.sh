#!/bin/bash
# curl -fsSL https://raw.githubusercontent.com/yelrambob/ubuntu/main/install_dotfiles.sh | bash
#
# Installs this repo's shell files (.bashrc, .bash_aliases, .bash_functions,
# .bash_email) into your home folder as SYMLINKS pointing at a clone of the
# repo, so a later `git pull` (or `pullgit`) updates your shell instantly.
# Any existing file is moved to <name>.bak-<timestamp> first, never deleted.
#
# Run as your normal user, NOT with sudo (it would install into /root).

set -e

if [[ $1 == -h || $1 == --help ]]; then
  echo "Usage: install_dotfiles.sh [--copy]"
  echo "  Symlinks .bashrc, .bash_aliases, .bash_functions and .bash_email from"
  echo "  this repo into \$HOME (backing up existing files), then creates"
  echo "  ~/.bash_secrets from the example if you don't have one yet."
  echo "  --copy   copy the files instead of symlinking them"
  echo "  If not run from inside a clone, the repo is cloned to ~/ubuntu first."
  exit 0
fi

if [[ $EUID -eq 0 && -n $SUDO_USER ]]; then
  echo "Don't run this with sudo — it would install into /root. Run it as $SUDO_USER." >&2
  exit 1
fi

MODE=link
[[ $1 == --copy ]] && MODE=copy

# Find the repo: the folder this script is in, or clone/update ~/ubuntu.
SRC=""
if [[ -n ${BASH_SOURCE[0]} && -f "$(dirname "${BASH_SOURCE[0]}")/.bash_aliases" ]]; then
  SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  SRC="$HOME/ubuntu"
  command -v git >/dev/null || { sudo apt-get update && sudo apt-get install -y git; }
  if [[ -d $SRC/.git ]]; then
    git -C "$SRC" pull --ff-only
  else
    git clone https://github.com/yelrambob/ubuntu.git "$SRC"
  fi
fi
echo "Using repo at: $SRC"

stamp=$(date +%Y%m%d-%H%M%S)
for f in .bashrc .bash_aliases .bash_functions .bash_email; do
  [[ -f $SRC/$f ]] || continue
  dest="$HOME/$f"
  # Already linked to the right place? Nothing to do.
  if [[ -L $dest && "$(readlink -f "$dest")" == "$SRC/$f" ]]; then
    echo "  ok      $f (already linked)"
    continue
  fi
  if [[ -e $dest || -L $dest ]]; then
    mv "$dest" "$dest.bak-$stamp"
    echo "  backup  $f -> $f.bak-$stamp"
  fi
  if [[ $MODE == link ]]; then
    ln -s "$SRC/$f" "$dest"
    echo "  linked  $f -> $SRC/$f"
  else
    cp "$SRC/$f" "$dest"
    echo "  copied  $f"
  fi
done

if [[ ! -f $HOME/.bash_secrets && -f $SRC/.bash_secrets.example ]]; then
  cp "$SRC/.bash_secrets.example" "$HOME/.bash_secrets"
  chmod 600 "$HOME/.bash_secrets"
  echo "  created ~/.bash_secrets from the example — edit it to add your real values"
fi

# Ubuntu login shells (SSH, console) read ~/.profile, which sources ~/.bashrc.
# Make sure a ~/.bash_profile doesn't exist that would skip ~/.profile.
if [[ -f $HOME/.bash_profile ]] && ! grep -q 'bashrc\|\.profile' "$HOME/.bash_profile"; then
  echo
  echo "NOTE: ~/.bash_profile exists and doesn't load ~/.bashrc, so SSH/login"
  echo "      shells will skip your aliases. Add this line to it:"
  echo '        [ -f ~/.bashrc ] && . ~/.bashrc'
fi

command -v curl >/dev/null || echo "NOTE: install curl (sudo apt install curl) so the prompt can show your public IP."

echo
echo "Done. Open a new terminal, or run:  source ~/.bashrc"
