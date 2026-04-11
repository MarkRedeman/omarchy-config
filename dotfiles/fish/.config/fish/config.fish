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
