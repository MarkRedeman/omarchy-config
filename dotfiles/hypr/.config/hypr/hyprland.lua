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

-- Make Emacs fully opaque (override the default ~98% window opacity).
o.window("^(emacs)$", { tag = "-default-opacity", opacity = "1 1" })
