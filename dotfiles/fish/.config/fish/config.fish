set fish_greeting ""

# Use default (Emacs-style) keybindings instead of vi mode from omarchy-fish
fish_default_key_bindings

# Editor
set -x EDITOR "emacsclient -t"
set -x VISUAL "emacsclient -c"

# Personal PATH additions (omarchy handles ~/.local/bin)
fish_add_path $HOME/.cargo/bin
fish_add_path $HOME/.juliaup/bin
fish_add_path $HOME/.config/composer/vendor/bin
fish_add_path $HOME/.opencode/bin

# Emacs ansi-term support
if test -n "$EMACS"
    set -x TERM eterm-color
end

# Personal aliases (omarchy-fish provides g, ga, gcam, gd, etc.)
alias gl "git log --oneline --all --graph --decorate"

# Corporate proxy: always-on via alpaca (systemd user service).
# alpaca runs at localhost:3128 and evaluates Intel's PAC file per-request.
# When on VPN, corporate traffic routes through the Intel proxy.
# When off VPN, the proxy is unreachable so alpaca auto-falls back to DIRECT.
# See proxy.md for details.
set -gx http_proxy http://localhost:3128
set -gx HTTP_PROXY http://localhost:3128
set -gx https_proxy http://localhost:3128
set -gx HTTPS_PROXY http://localhost:3128
set -gx no_proxy localhost,127.0.0.0/8,::1
set -gx NO_PROXY localhost,127.0.0.0/8,::1
