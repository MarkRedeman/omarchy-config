-- Extra startup processes.
--
-- Omarchy defaults already start the shell, session services, monitor
-- watcher, and post-boot hooks (see default/hypr/autostart.lua).

-- Load hyprpm plugins (hy3 for i3-style tiling), then reload so the
-- plugin config section (plugins.lua) parses with hy3's config registered.
o.exec_on_start("hyprpm reload -n && sleep 1 && hyprctl reload")
