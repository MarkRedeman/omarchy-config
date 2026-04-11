# Password Store (pass)

Setup instructions for [pass](https://www.passwordstore.org/), the standard Unix password manager, using GPG encryption with a git-backed store.

## Install

Omarchy already ships `gnupg` and `pinentry`, so you only need `pass` itself:

```bash
omarchy-pkg-add pass
```

## Import your GPG key

Copy your exported private key file to the machine (e.g., via USB drive or scp), then import it:

```bash
# Import the secret key
gpg --import /path/to/private-key.asc

# Verify the key was imported
gpg --list-secret-keys
```

You should see your key with `sec` (secret) next to it. Note the key ID -- the long hex string on the `sec` line, or the last 8+ characters of it.

### Trust the key

After importing, you need to mark the key as ultimately trusted (since it's your own key):

```bash
gpg --edit-key <KEY_ID>
```

At the `gpg>` prompt:

```
gpg> trust
  # Select option 5 (ultimate trust)
gpg> quit
```

## Clone your password store

```bash
git clone <your-pass-repo-url> ~/.password-store
```

Verify it works:

```bash
pass
pass show some/entry
```

## Configure git inside the store

If your store already has a git remote, `pass git pull` and `pass git push` will work out of the box. Otherwise:

```bash
pass git init
pass git remote add origin <your-pass-repo-url>
```

## Extend GPG key expiry

GPG keys have an expiration date. When a key is nearing expiry, extend it rather than creating a new one -- this preserves your ability to decrypt old passwords.

### Check current expiry

```bash
gpg --list-keys <KEY_ID>
```

Look for `[expires: YYYY-MM-DD]` next to the `pub` and `sub` lines.

### Extend the primary key

```bash
gpg --edit-key <KEY_ID>
```

At the `gpg>` prompt:

```
gpg> expire
  # Enter the new lifetime, e.g. "2y" for 2 years, "1y" for 1 year, "0" for no expiry
gpg> save
```

### Extend subkeys

Each subkey (encryption, signing) has its own expiry. Extend them individually:

```bash
gpg --edit-key <KEY_ID>
```

```
gpg> list
  # Note the subkey index numbers (sub lines)

gpg> key 1
  # Selects the first subkey (marked with *)

gpg> expire
  # Enter the new lifetime, e.g. "2y"

gpg> key 1
  # Deselect the first subkey

gpg> key 2
  # Select the next subkey, repeat for each

gpg> expire

gpg> save
```

### Publish the updated key

After extending expiry, re-export and back up your key, and push to any keyservers if you use them:

```bash
# Back up updated private key
gpg --export-secret-keys --armor <KEY_ID> > private-key-updated.asc

# Back up public key
gpg --export --armor <KEY_ID> > public-key-updated.asc

# Push to keyserver (optional)
gpg --send-keys <KEY_ID>
```

Store the updated backup securely.

## Daily usage

```bash
# List all entries
pass

# Show a password (copies to clipboard for 45s with -c)
pass show email/personal
pass -c email/personal

# Add or edit an entry
pass insert social/mastodon
pass edit social/mastodon

# Generate a new password
pass generate shopping/amazon 24

# Sync with remote
pass git pull
pass git push
```

## Browser integration

For browser autofill, install [browserpass](https://github.com/browserpass/browserpass-extension):

```bash
omarchy-pkg-add browserpass browserpass-chromium
```

Then install the [browserpass extension](https://github.com/browserpass/browserpass-extension#install) in Chromium.

## Walker integration (planned)

Walker/Elephant has a [community `pass` provider](https://github.com/abenz1267/elephant-community) that can list pass entries and copy passwords to the clipboard. A keybinding (`SUPER+ALT+P`) is reserved in `bindings.conf` for this.

### Community provider (quick but less secure)

The existing community provider decrypts **all** passwords at load time and caches them in Elephant's memory. To use it as-is:

```bash
elephant community install pass
systemctl --user restart elephant
```

Then uncomment the `SUPER+ALT+P` line in `bindings.conf`.

### Custom safer provider (preferred, not yet implemented)

A better approach: write a custom Lua provider that only lists entry names (no decryption), then decrypts the selected entry on demand via `pass -c` (which copies to clipboard for 45s and auto-clears). This avoids holding all passwords in memory.

The custom provider would go in `~/.config/elephant/plugins/pass.lua` and:

1. List entries by scanning `~/.password-store/` for `.gpg` files (no `pass show`)
2. On selection, run `pass -c <entry>` to decrypt and copy just that one password
3. Show a notification confirming the copy

See the [elephant-community repo](https://github.com/abenz1267/elephant-community) for the existing `pass.lua` as a starting point, and the [Elephant plugin docs](https://github.com/abenz1267/walker/wiki/Modules) for the Lua provider API.

## GPG agent caching

To avoid typing your passphrase constantly, configure the GPG agent cache lifetime in `~/.gnupg/gpg-agent.conf`:

```
default-cache-ttl 43200
max-cache-ttl 43200
```

This caches the passphrase for 12 hours while your session is unlocked. In this config, the lock flow also clears the GPG agent cache, so locking your machine requires re-entry after unlock. Reload with:

```bash
gpgconf --kill gpg-agent
```

Omarchy ships `pinentry` which handles the passphrase dialog on Wayland. If the pinentry prompt doesn't appear, verify the agent is using the right pinentry program:

```bash
# Check which pinentry is active
gpgconf --list-options gpg-agent | grep pinentry

# Override if needed in ~/.gnupg/gpg-agent.conf
# pinentry-program /usr/bin/pinentry-gnome3
```
