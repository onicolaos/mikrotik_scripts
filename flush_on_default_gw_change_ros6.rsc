# this script checks when the default active route changes and flushes connections on long timeouts
:do {
    :global prevHop
    :local currHop
    /ip route
    :foreach aR in=[find dst-address=0.0.0.0/0 active=yes] do={
        :if ([:len [get $aR routing-mark]] = 0) do={
            :set currHop [get $aR gateway]
            :if ($currHop != $prevHop && [:len $currHop] > 0) do={
                :if ([:len $prevHop] > 0) do={
                    :log info "Default Gateway next hop change detected. Flushing connections..."
                    /ip firewall connection remove [find where timeout>60]
                    :set prevHop $currHop
                } else={
                    :log info "Previous next hop was empty, probably due to first run or reboot. Not really a change. Trying again on the next iteration."
                    :set prevHop $currHop
                }
            }
        }
    }
    :if ([:len $currHop] = 0) do={
        :log info "Did not find an active default route. Maybe next time"
    }
}
