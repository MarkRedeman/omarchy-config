-- Control your input devices.
-- See https://wiki.hyprland.org/Configuring/Variables/#input
--
-- Only overrides are listed; Omarchy defaults already provide
-- follow_mouse, numlock, touchpad scroll_factor 0.4, and the
-- per-terminal scroll_touchpad rules.

hl.config({
  input = {
    kb_layout = "us",
    kb_variant = "altgr-intl",

    -- Caps Lock acts as an extra Ctrl (replaces Omarchy's compose:caps default)
    kb_options = "caps:ctrl_modifier",

    repeat_rate = 40,
    repeat_delay = 600,

    -- Omarchy defaults to clickfinger_behavior = true (2-finger press = right
    -- click), which drops the bottom-right button area. Button areas give the
    -- corner press back; two-finger *tap* still right-clicks because
    -- tap-to-click maps by finger count regardless of click method.
    touchpad = {
      clickfinger_behavior = false,
    },
  },
})
