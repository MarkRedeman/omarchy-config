#!/usr/bin/env bash
#
# Capture or apply ~/.config/omarchy/shell.json.
#
# shell.json is intentionally not stowed. omarchy-shell rewrites it with
# atomic writes (temp file + rename), which replaces a stow symlink with a
# regular file. This script moves the live file into the repo (pull) or the
# repo file into the live location (push) explicitly.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIVE="$HOME/.config/omarchy/shell.json"
REPO="$REPO_DIR/dotfiles/omarchy/.config/omarchy/shell.json"

usage() {
    cat <<'USAGE'
Usage: scripts/shell-config.sh <command>

Commands:
  diff   Show differences between the live shell.json and the repo copy
  pull   Copy the live shell.json into the repo (live -> repo)
  push   Copy the repo shell.json to the live location (repo -> live),
         backing up the current live file first

shell.json is not stowed because omarchy-shell rewrites it atomically, which
replaces a symlink with a regular file. Commit pulled changes like any other
tracked file.
USAGE
}

validate_json() {
    local file=$1 label=$2

    if [[ ! -f $file ]]; then
        echo "error: $label not found: $file" >&2
        exit 1
    fi

    if command -v jq >/dev/null 2>&1; then
        jq empty "$file" >/dev/null 2>&1 || {
            echo "error: $label is not valid JSON: $file" >&2
            exit 1
        }
    else
        python3 -m json.tool "$file" >/dev/null 2>&1 || {
            echo "error: $label is not valid JSON: $file" >&2
            exit 1
        }
    fi
}

copy_atomic() {
    local source=$1 destination=$2 mode=$3
    local temporary

    temporary="$(mktemp "$destination.XXXXXX")"
    if ! install -m "$mode" "$source" "$temporary"; then
        rm -f "$temporary"
        return 1
    fi
    mv -f "$temporary" "$destination"
}

diff_config() {
    validate_json "$LIVE" "live shell.json"
    validate_json "$REPO" "repo shell.json"

    diff -u \
        --label "live: $LIVE" \
        --label "repo: $REPO" \
        "$LIVE" "$REPO"
}

pull_config() {
    validate_json "$LIVE" "live shell.json"

    if [[ -f $REPO ]] && cmp -s "$LIVE" "$REPO"; then
        echo "shell.json is already up to date."
        return 0
    fi

    copy_atomic "$LIVE" "$REPO" 644
    echo "Pulled live shell.json into $REPO"
    echo "Review and commit the change with git."
}

push_config() {
    validate_json "$REPO" "repo shell.json"

    mkdir -p "$(dirname "$LIVE")"
    if [[ -e $LIVE ]]; then
        local backup
        backup="$LIVE.bak.$(date +%Y%m%d%H%M%S%N)"
        cp -p "$LIVE" "$backup"
        echo "Backed up live shell.json to $backup"
    fi

    copy_atomic "$REPO" "$LIVE" 600
    echo "Applied repo shell.json to $LIVE"
    echo "The running shell reloads it automatically; run omarchy-restart-shell if it does not."
}

case "${1:-}" in
    diff) diff_config ;;
    pull) pull_config ;;
    push) push_config ;;
    -h | --help | help) usage ;;
    *)
        usage >&2
        exit 2
        ;;
esac
