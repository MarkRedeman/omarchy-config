#!/usr/bin/env bash
set -euo pipefail

omarchy-lock-screen

if command -v gpgconf >/dev/null 2>&1; then
    gpgconf --kill gpg-agent >/dev/null 2>&1 || true
fi
