-- See https://wiki.hyprland.org/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

-- GDK_SCALE is integer-only (GTK3). Set to 2 so GTK3 apps render at 2x
-- then Hyprland downscales to match the fractional monitor scale below.
hl.env("GDK_SCALE", "2")

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1.25 })

-- Straight 1x setup for low-resolution displays like 1080p or 1440p
-- hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
