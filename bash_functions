# ===== numbered directory navigation =====================================
# lsn          list everything in the current dir (hidden too), numbered
# cdn   <n>    cd into item <n>            (auto re-lists)
# nanon <n>... open item(s) <n> in nano    (sudo only when needed)
# catn  <n>... print item(s) <n>
# sour  <n>... print the resolved path(s) of item <n>    (for use in `$(sour N)`)
# mvn   <n>... <dest>   move item(s) <n> into/to <dest>  (auto re-lists)
# cpn   <n>... <dest>   copy item(s) <n> into/to <dest>  (auto re-lists)
# rmx   <n>... remove item(s) <n>          (confirms first, auto re-lists)
# Numbers come from the last `lsn`; re-run lsn if the dir changed.
# =========================================================================

lsn() {
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
        sudo nano -- "${files[@]}"
    else
        nano -- "${files[@]}"
    fi
}

catn() {
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
        # String arg: repo/directory name, created/overwritten in cwd
        name=$1
        parent="$PWD"
        target="$PWD/$name"
    fi

    local repo_url="https://github.com/${repo_user}/${name}.git"

    echo "pullgit: about to DELETE and re-clone:"
    echo "  target : $target"
    echo "  source : $repo_url"
    local reply
    read -r -p "Proceed? [y/N] " reply
    [[ $reply == [Yy]* ]] || { echo "pullgit: cancelled"; return 1; }

    if (( same_dir )); then
        cd "$parent" || return 1
        rm -rf -- "$name"
        git clone -- "$repo_url" "$name" || { echo "pullgit: clone failed" >&2; return 1; }
        cd "$name" || return 1
    else
        rm -rf -- "$target"
        git clone -- "$repo_url" "$target" || { echo "pullgit: clone failed" >&2; return 1; }
    fi

    lsn
}
