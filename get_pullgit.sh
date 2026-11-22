# get_pullgit.sh — bootstrap a fresh machine with this repo's shell setup.
#
# Copy this WHOLE file and paste it into a terminal (as your normal user, not
# root). It is written to be pasted: it never calls `exit`, so it won't close
# your terminal. It can also be run with:  source get_pullgit.sh
#
# What it does:
#   1. installs git + curl if missing
#   2. clones yelrambob/ubuntu to ~/ubuntu (or updates it if already there)
#   3. links .bashrc, .bash_aliases, .bash_functions, .bash_email into ~
#      (existing files are backed up to <name>.bak-<timestamp>)
#   4. loads them into THIS terminal, so `pullgit`, `lsn`, your aliases etc.
#      work immediately
# Afterwards, to update everything later:  cd ~/ubuntu && pullgit

{
  __repo="https://github.com/yelrambob/ubuntu.git"
  __dir="$HOME/ubuntu"
  # Branch with the latest fixes; falls back to main if it no longer exists.
  __branch="claude/cool-turing-llmhah"

  echo "==> Checking for git and curl"
  if ! command -v git >/dev/null || ! command -v curl >/dev/null; then
    sudo apt-get update && sudo apt-get install -y git curl
  fi

  if ! git ls-remote --exit-code --heads "$__repo" "$__branch" >/dev/null 2>&1; then
    __branch="main"
  fi
  echo "==> Using branch: $__branch"

  if [ -d "$__dir/.git" ]; then
    echo "==> Updating $__dir (untracked files are kept)"
    git -C "$__dir" fetch origin "$__branch" &&
    git -C "$__dir" checkout -B "$__branch" "origin/$__branch"
  else
    echo "==> Cloning into $__dir"
    git clone --branch "$__branch" "$__repo" "$__dir"
  fi

  if [ -f "$__dir/install_dotfiles.sh" ]; then
    echo "==> Linking shell files into $HOME"
    bash "$__dir/install_dotfiles.sh"
    echo "==> Loading them into this terminal"
    . "$HOME/.bashrc"
    if type pullgit >/dev/null 2>&1; then
      echo
      echo "All set: pullgit, lsn, and your aliases are ready ($(alias | wc -l) aliases loaded)."
      echo "Update later with:  cd ~/ubuntu && pullgit"
    else
      echo "Something went wrong — pullgit isn't defined. Check: ls -la ~ | grep bash"
    fi
  else
    echo "Clone/update failed — see the git error above."
  fi

  unset __repo __dir __branch
}
