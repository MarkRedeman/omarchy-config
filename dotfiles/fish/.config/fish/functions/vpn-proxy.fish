# Check corporate proxy status.
# Proxy env vars are set globally in config.fish (always on via localhost:3128).
# alpaca runs as a systemd user service and auto-falls back to DIRECT off VPN.
#
# Usage: vpn-proxy [status|restart]

function vpn-proxy
    switch "$argv[1]"
        case on status ''
            if set -q http_proxy
                echo "Proxy is ON"
                echo "  http_proxy  = $http_proxy"
                echo "  https_proxy = $https_proxy"
                echo "  no_proxy    = $no_proxy"
                if systemctl --user is-active --quiet alpaca.service 2>/dev/null
                    echo "  alpaca      = running (systemd)"
                else
                    echo "  alpaca      = NOT running (proxy will fail!)"
                end
            else
                echo "Proxy env vars not set (check config.fish)"
            end

        case restart
            # Force alpaca to clear its 5-minute proxy blocklist and reload the
            # local PAC. Use this after (re)connecting the VPN if intranet
            # requests are still being routed DIRECT for up to 5 minutes.
            if systemctl --user restart alpaca.service 2>/dev/null
                echo "alpaca restarted: proxy blocklist cleared, PAC reloaded."
            else
                echo "Failed to restart alpaca.service"
                return 1
            end

        case '*'
            echo "Usage: vpn-proxy [status|restart]"
            return 1
    end
end
