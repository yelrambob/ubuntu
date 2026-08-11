# ===== numbered directory navigation =====================================
# lsn          list everything in the current dir (hidden too), numbered
# cdn   <n>    cd into item <n>            (auto re-lists)
# nanon <n>... open item(s) <n> in nano    (sudo only when needed)
# catn  <n>... print item(s) <n>
# sour  <n>... print the resolved path(s) of item <n>    (for use in `$(sour N)`)
# mvn   <n>... <dest>   move item(s) <n> into/to <dest>  (auto re-lists)
# cpn   <n>... <dest>   copy item(s) <n> into/to <dest>  (auto re-lists)
# rmx   <n>... remove item(s) <n>          (confirms first, auto re-lists)
# pullgit <reponame> (pulls latest, keeps anything untracked)
# pushgit [<n>|<dir>] [commit message]   stage, commit, and push the target repo
#   (warns on and excludes files that look like secrets, e.g. credentials.json)
# Numbers come from the last `lsn`; re-run lsn if the dir changed.
# =========================================================================

lsn() {
    if [[ $1 == -h || $1 == --help ]]; then
        echo "Usage: lsn"
        echo "  List everything in the current directory (hidden files too), numbered."
        echo "  Populates LSN_ITEMS[] for use by cdn/nanon/catn/sour/mvn/cpn/rmx/pullgit/pushgit."
        return 0
    fi
    LSN_ITEMS=()
    local i=1 item reset='' dir='' lnk='' exe=''
    if [[ -t 1 ]]; then
        reset=$'\033[0m'; dir=$'\033[1;34m'; lnk=$'\033[1;36m'; exe=$'\033[1;32m'
    fi
    while IFS= read -r -d '' item; do
        LSN_ITEMS[i]="$item"
        if   [[ -L $item ]]; then printf '%3d  %s%s%s\n'  "$i" "$lnk" "$item" "$reset"
        elif [[ -d $item ]]; then printf '%3d  %s%s%s/\n' "$i" "$dir" "$item" "$reset"
        elif [[ -x $item ]]; then printf '%3d  %s%s%s\n'  "$i" "$exe" "$item" "$reset"
        else                      printf '%3d  %s\n'      "$i" "$item"
        fi
        ((i++))
    done < <(shopt -s dotglob nullglob; for f in *; do printf '%s\0' "$f"; done | LC_ALL=C sort -z)
    (( ${#LSN_ITEMS[@]} )) || echo "(empty directory)"
}

cdn() {
    if [[ $1 == -h || $1 == --help ]]; then
        echo "Usage: cdn <number>"
        echo "  cd into the item numbered <number> from the last lsn listing (auto re-lists)."
        return 0
    fi
    local n=$1
    [[ $n =~ ^[0-9]+$ ]] || { echo "cdn: usage: cdn <number> (run lsn first)" >&2; return 2; }
    n=$((10#$n))
    (( ${#LSN_ITEMS[@]} )) || { echo "cdn: no list yet — run lsn first" >&2; return 1; }
    local target=${LSN_ITEMS[n]}
    [[ -n $target ]] || { echo "cdn: no item numbered $n" >&2; return 1; }
    [[ -d $target ]] || { echo "cdn: '$target' is not a directory" >&2; return 1; }
    cd -- "$target" && lsn
}

nanon() {
    if [[ $1 == -h || $1 == --help ]]; then
        echo "Usage: nanon <number> [number...]"
        echo "  Open item(s) <number> (from the last lsn listing) in nano."
        echo "  Uses sudo automatically when the target isn't writable."
        return 0
    fi
    (( $# )) || { echo "nanon: usage: nanon <number> [number...]" >&2; return 2; }
    (( ${#LSN_ITEMS[@]} )) || { echo "nanon: no list yet — run lsn first" >&2; return 1; }
    local n idx target files=() need_sudo=0
    for n in "$@"; do
        [[ $n =~ ^[0-9]+$ ]] || { echo "nanon: '$n' is not a number" >&2; return 2; }
        idx=$((10#$n)); target=${LSN_ITEMS[idx]}
        [[ -n $target ]] || { echo "nanon: no item numbered $n" >&2; return 1; }
        [[ -d $target ]] && { echo "nanon: '$target' is a directory" >&2; return 1; }
        if [[ -e $target && ! -w $target ]] || [[ ! -e $target && ! -w . ]]; then
            need_sudo=1
        fi
        files+=("$target")
    done
    if (( EUID != 0 && need_sudo )); then
        sudo nano -l -- "${files[@]}"
    else
        nano -l -- "${files[@]}"
    fi
}

catn() {
    if [[ $1 == -h || $1 == --help ]]; then
        echo "Usage: catn <number> [number...]"
        echo "  Print the contents of item(s) <number> from the last lsn listing."
        return 0
    fi
    (( $# )) || { echo "catn: usage: catn <number> [number...]" >&2; return 2; }
    (( ${#LSN_ITEMS[@]} )) || { echo "catn: no list yet — run lsn first" >&2; return 1; }
    local n idx target files=()
    for n in "$@"; do
        [[ $n =~ ^[0-9]+$ ]] || { echo "catn: '$n' is not a number" >&2; return 2; }
        idx=$((10#$n)); target=${LSN_ITEMS[idx]}
        [[ -n $target ]] || { echo "catn: no item numbered $n" >&2; return 1; }
        [[ -d $target ]] && { echo "catn: '$target' is a directory" >&2; return 1; }
        files+=("$target")
    done
    cat -- "${files[@]}"
}

sour() {
    if [[ $1 == -h || $1 == --help ]]; then
        echo "Usage: sour <number> [number...]"
        echo "  Print the resolved path(s) of item <number> from the last lsn listing."
        echo "  Intended for use inside \$(sour N)."
        return 0
    fi
    (( $# )) || { echo "sour: usage: sour <number> [number...]" >&2; return 2; }
    (( ${#LSN_ITEMS[@]} )) || { echo "sour: no list yet — run lsn first" >&2; return 1; }
    local n idx target
    for n in "$@"; do
        [[ $n =~ ^[0-9]+$ ]] || { echo "sour: '$n' is not a number" >&2; return 2; }
        idx=$((10#$n)); target=${LSN_ITEMS[idx]}
        [[ -n $target ]] || { echo "sour: no item numbered $n" >&2; return 1; }
        printf '%s\n' "$target"
    done
}

mvn() {
    if [[ $1 == -h || $1 == --help ]]; then
        echo "Usage: mvn <number> [number...] <destination>"
        echo "  Move item(s) <number> from the last lsn listing into/to <destination>."
        echo "  <destination> may be a path, or -<number> to target another lsn item's"
        echo "  resolved path (e.g. mvn 13 -15 moves item 13 into/to item 15)."
        echo "  Uses sudo automatically when needed; auto re-lists afterward."
        return 0
    fi
    (( $# >= 2 )) || { echo "mvn: usage: mvn <number> [number...] <destination>" >&2; return 2; }
    (( ${#LSN_ITEMS[@]} )) || { echo "mvn: no list yet — run lsn first" >&2; return 1; }
    local n idx target targets=() need_sudo=0
    local dest=${*: -1}
    local nums=("${@:1:$#-1}")
    for n in "${nums[@]}"; do
        [[ $n =~ ^[0-9]+$ ]] || { echo "mvn: '$n' is not a number" >&2; return 2; }
        idx=$((10#$n)); target=${LSN_ITEMS[idx]}
        [[ -n $target ]] || { echo "mvn: no item numbered $n" >&2; return 1; }
        targets+=("$target")
    done
    if [[ $dest =~ ^-([0-9]+)$ ]]; then
        idx=$((10#${BASH_REMATCH[1]}))
        target=${LSN_ITEMS[idx]}
        [[ -n $target ]] || { echo "mvn: no item numbered ${BASH_REMATCH[1]}" >&2; return 1; }
        dest=$target
    fi
    if [[ -e $dest && ! -w $dest ]] || [[ ! -e $dest && ! -w $(dirname -- "$dest") ]] || [[ ! -w . ]]; then
        need_sudo=1
    fi
    if (( EUID != 0 && need_sudo )); then
        sudo mv -- "${targets[@]}" "$dest"
    else
        mv -- "${targets[@]}" "$dest"
    fi
    lsn
}

cpn() {
    if [[ $1 == -h || $1 == --help ]]; then
        echo "Usage: cpn <number> [number...] <destination>"
        echo "  Copy item(s) <number> from the last lsn listing into/to <destination>."
        echo "  Uses sudo automatically when needed; auto re-lists afterward."
        return 0
    fi
    (( $# >= 2 )) || { echo "cpn: usage: cpn <number> [number...] <destination>" >&2; return 2; }
    (( ${#LSN_ITEMS[@]} )) || { echo "cpn: no list yet — run lsn first" >&2; return 1; }
    local n idx target targets=() need_sudo=0
    local dest=${*: -1}
    local nums=("${@:1:$#-1}")
    for n in "${nums[@]}"; do
        [[ $n =~ ^[0-9]+$ ]] || { echo "cpn: '$n' is not a number" >&2; return 2; }
        idx=$((10#$n)); target=${LSN_ITEMS[idx]}
        [[ -n $target ]] || { echo "cpn: no item numbered $n" >&2; return 1; }
        targets+=("$target")
    done
    if [[ -e $dest && ! -w $dest ]] || [[ ! -e $dest && ! -w $(dirname -- "$dest") ]]; then
        need_sudo=1
    fi
    if (( EUID != 0 && need_sudo )); then
        sudo cp -r -- "${targets[@]}" "$dest"
    else
        cp -r -- "${targets[@]}" "$dest"
    fi
    lsn
}

rmx() {
    if [[ $1 == -h || $1 == --help ]]; then
        echo "Usage: rmx <number> [number...]"
        echo "  Remove item(s) <number> from the last lsn listing."
        echo "  Confirms before deleting; uses sudo automatically when needed; auto re-lists afterward."
        return 0
    fi
    (( $# )) || { echo "rmx: usage: rmx <number> [number...]" >&2; return 2; }
    (( ${#LSN_ITEMS[@]} )) || { echo "rmx: no list yet — run lsn first" >&2; return 1; }
    local n idx target targets=() need_sudo=0
    for n in "$@"; do
        [[ $n =~ ^[0-9]+$ ]] || { echo "rmx: '$n' is not a number" >&2; return 2; }
        idx=$((10#$n)); target=${LSN_ITEMS[idx]}
        [[ -n $target ]] || { echo "rmx: no item numbered $n" >&2; return 1; }
        targets+=("$target")
    done
    [[ ! -w . ]] && need_sudo=1
    printf 'rmx: about to remove %d item(s):\n' "${#targets[@]}"
    printf '  %s\n' "${targets[@]}"
    local reply
    read -r -p "Proceed? [y/N] " reply
    [[ $reply == [Yy]* ]] || { echo "rmx: cancelled"; return 1; }
    if (( EUID != 0 && need_sudo )); then
        sudo rm -rf -- "${targets[@]}"
    else
        rm -rf -- "${targets[@]}"
    fi
    lsn
}

pullgit() {
    if [[ $1 == -h || $1 == --help ]]; then
        echo "Usage: pullgit [<number>|<name>]"
        echo "  Pull the latest changes for a yelrambob/<name> repo, keeping untracked files."
        echo "  No arg   : treat the current directory as the repo to update."
        echo "  <number> : pull the name from the last lsn listing, clone/update in cwd."
        echo "  <name>   : clone/update yelrambob/<name> in the current directory."
        return 0
    fi
    local repo_user="yelrambob"
    local name target parent same_dir=0

    if [[ $# -eq 0 ]]; then
        # No args: target is the directory you're currently in
        name=$(basename -- "$PWD")
        parent=$(dirname -- "$PWD")
        target="$PWD"
        same_dir=1
    elif [[ $1 =~ ^[0-9]+$ ]]; then
        # Numeric arg: pull the name from the last `lsn` listing
        (( ${#LSN_ITEMS[@]} )) || { echo "pullgit: no list yet — run lsn first" >&2; return 1; }
        local idx=$((10#$1))
        name=${LSN_ITEMS[idx]}
        [[ -n $name ]] || { echo "pullgit: no item numbered $1" >&2; return 1; }
        parent="$PWD"
        target="$PWD/$name"
    else
        # String arg: repo/directory name in cwd
        name=$1
        parent="$PWD"
        target="$PWD/$name"
    fi

    local repo_url="https://github.com/${repo_user}/${name}.git"

    if [[ -d "$target/.git" ]]; then
        echo "pullgit: updating existing repo in place (untracked files are kept):"
        echo "  target : $target"
        echo "  source : $repo_url"

        local dirty
        dirty=$(git -C "$target" status --porcelain --untracked-files=no)
        if [[ -n $dirty ]]; then
            echo "  ⚠️  uncommitted changes to TRACKED files will be discarded:"
            echo "$dirty" | sed 's/^/    /'
        fi

        local reply
        read -r -p "Proceed? [y/N] " reply
        [[ $reply == [Yy]* ]] || { echo "pullgit: cancelled"; return 1; }

        git -C "$target" fetch origin || { echo "pullgit: fetch failed" >&2; return 1; }

        local default_branch
        default_branch=$(git -C "$target" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
        default_branch=${default_branch#origin/}
        [[ -n $default_branch ]] || default_branch="main"

        git -C "$target" reset --hard "origin/${default_branch}" || { echo "pullgit: reset failed" >&2; return 1; }
    else
        echo "pullgit: no existing repo found here — cloning fresh:"
        echo "  target : $target"
        echo "  source : $repo_url"

        local reply
        read -r -p "Proceed? [y/N] " reply
        [[ $reply == [Yy]* ]] || { echo "pullgit: cancelled"; return 1; }

        mkdir -p -- "$parent"
        git clone -- "$repo_url" "$target" || { echo "pullgit: clone failed" >&2; return 1; }
    fi

    (( same_dir )) && cd -- "$target"
    lsn
}

pushgit() {
    if [[ $1 == -h || $1 == --help ]]; then
        echo "Usage: pushgit [<number>|<dir>] [commit message]"
        echo "  Stage, commit, and push the target repo."
        echo "  No dir arg : use the current directory as the repo."
        echo "  <number>   : target the dir named at that position in the last lsn listing."
        echo "  <dir>      : target that directory directly."
        echo "  Warns on and excludes files that look like secrets (e.g. credentials.json, .env, *.pem)."
        return 0
    fi
    local repo_dir="$PWD" arg1="$1" msg

    if [[ -n $arg1 && $arg1 =~ ^[0-9]+$ ]]; then
        # Numeric arg: pull the name from the last `lsn` listing
        (( ${#LSN_ITEMS[@]} )) || { echo "pushgit: no list yet — run lsn first" >&2; return 1; }
        local idx=$((10#$arg1))
        local name=${LSN_ITEMS[idx]}
        [[ -n $name ]] || { echo "pushgit: no item numbered $arg1" >&2; return 1; }
        [[ -d $name ]] || { echo "pushgit: '$name' is not a directory" >&2; return 1; }
        repo_dir="$PWD/$name"
        shift
        msg="$*"
    elif [[ -n $arg1 && -d $arg1 ]]; then
        # String arg that's an existing directory: treat as the target
        repo_dir="$PWD/$arg1"
        shift
        msg="$*"
    else
        # No dir arg — whole thing (if any) is the commit message
        msg="$*"
    fi

    [[ -d "$repo_dir/.git" ]] || { echo "pushgit: '$repo_dir' is not a git repo" >&2; return 1; }

    local branch
    branch=$(git -C "$repo_dir" branch --show-current)
    [[ -n $branch ]] || { echo "pushgit: not on a branch (detached HEAD?)" >&2; return 1; }

    local status
    status=$(git -C "$repo_dir" status --porcelain)
    if [[ -z $status ]]; then
        echo "pushgit: nothing to commit — working tree clean"
        return 0
    fi

    echo "pushgit: changes in $repo_dir"
    git -C "$repo_dir" status --short

    # Never auto-stage anything that looks like a secret, gitignored or not
    local suspicious
    suspicious=$(echo "$status" | awk '{print $2}' | \
        grep -Ei '(^|/)\.env($|\.)|credentials\.json$|token\.pickle$|\.pem$|\.key$|id_rsa|secrets?\.')
    if [[ -n $suspicious ]]; then
        echo "  ⚠️  excluding these from the commit — they look like credentials/secrets:"
        echo "$suspicious" | sed 's/^/    /'
    fi

    if [[ -z $msg ]]; then
        read -r -p "Commit message: " msg
        [[ -n $msg ]] || { echo "pushgit: cancelled — empty commit message"; return 1; }
    fi

    echo "  branch  : $branch"
    echo "  message : $msg"
    local reply
    read -r -p "Stage, commit, and push? [y/N] " reply
    [[ $reply == [Yy]* ]] || { echo "pushgit: cancelled"; return 1; }

    git -C "$repo_dir" add -A
    if [[ -n $suspicious ]]; then
        while IFS= read -r f; do
            [[ -n $f ]] && git -C "$repo_dir" reset -q -- "$f"
        done <<< "$suspicious"
    fi

    git -C "$repo_dir" commit -m "$msg" || { echo "pushgit: commit failed (nothing staged?)" >&2; return 1; }
    git -C "$repo_dir" push -u origin "$branch" || { echo "pushgit: push failed" >&2; return 1; }

    echo "✅ pushed to origin/$branch"
}

