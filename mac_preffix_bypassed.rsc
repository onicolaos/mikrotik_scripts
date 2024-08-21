:do {
# Define the prefixes with descriptions
:local prefixes {
    {"prefix"="AA:BB:CC"; "description"="setTV01"};
    {"prefix"="11:22:33"; "description"="setTV02"};
}

# Get the current date
:local currentDate [/system clock get date]

# Iterate over each DHCP lease
:foreach lease in=[/ip dhcp-server lease find] do={

    # Get the MAC address of the lease
    :local mac [/ip dhcp-server lease get $lease mac-address]

    # Check if the MAC address matches any of the specified prefixes
    :local matched false
    :local matchedDescription ""
    :foreach p in=$prefixes do={
        :local prefix "$($p->"prefix")"
        :if ([:pick $mac 0 [:len $prefix]] = $prefix) do={
			:log info "$mac matched $prefix"
            :set matched true
            :set matchedDescription "$($p->"description")"
        }
    }

    # If the MAC address matches a prefix, check if it's already in Hotspot bindings
    :if ($matched) do={
        :local exists [/ip hotspot ip-binding find mac-address=$mac]

        # If not found in bindings, add it as a bypassed MAC address with a comment
        :if ([:len $exists] = 0) do={
            /ip hotspot ip-binding add mac-address=$mac type=bypassed comment="matched from $matchedDescription added on $currentDate"
        }
    }
}
}

# this script adds every mac address that matches one of the prefixes to the hotspot ip-binding as bypassed. useful when you have a set of devices like TV on a hotel that you want to be bypassed
