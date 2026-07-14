# Check corporate proxy status.
# Proxy env vars are set globally in config.fish (always on via localhost:3128).
# alpaca runs as a systemd user service and auto-falls back to DIRECT off VPN.
#
# Usage: vpn-proxy [status]

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

        case '*'
            echo "Usage: vpn-proxy [status]"
            return 1
    end
end
