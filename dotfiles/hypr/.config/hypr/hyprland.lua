-- Personal Hyprland configuration (Omarchy quattro).
--
-- Omarchy's package-owned defaults load first; the modules below override
-- them. Keep this file small — put changes in the matching topic file.

dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

require("default.hypr.omarchy")

require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.plugins")
require("hypr.autostart")


-- State-driven toggles (touchpad/touchscreen, workspace layouts, flags).
require("default.hypr.toggles")

-- Window opacity, pinned here instead of inherited from Omarchy's defaults so
-- a fresh deploy matches this machine. Every window gets the default-opacity
-- tag upstream; apps that should stay opaque drop the tag instead of setting
-- their own opacity (see Emacs below).
o.window({ tag = "default-opacity" }, { opacity = "0.985 0.96" })

-- Make Emacs fully opaque (override the default ~98% window opacity).
-- Emacs' window class is "Emacs"; Hyprland class regexes are case-sensitive.
o.window("(?i)^emacs$", { tag = "-default-opacity", opacity = "1 1" })

-- Chromium PWAs (Teams) keep the default-opacity tag, so they render at ~98%
-- and show the wallpaper through the window. Their class is
-- chrome-<app-id>-Default, which upstream's chromium-based-browser tag rule
-- does not catch. Pin them fully opaque.
o.window("^chrome-.*-Default$", { tag = "-default-opacity", opacity = "1 1" })

-- hyprmon: managed monitor profile include
require("hyprmon")
