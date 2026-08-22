-- Extra startup processes.
--
-- Omarchy defaults already start the shell, session services, monitor
-- watcher, and post-boot hooks (see default/hypr/autostart.lua).

-- Load hyprpm plugins (hy3 for i3-style tiling)
o.exec_on_start("hyprpm reload -n")
