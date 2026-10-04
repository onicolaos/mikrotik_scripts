# =====================================================================
# Mullvad WireGuard + PPPoE / Static / DHCP failover setup
# For a MikroTik hAP ac2 (RouterOS 7, legacy /interface wireless)
# running the DEFAULT configuration (reset-configuration with defaults).
#
# Usage: upload to the router and run   /import file-name=mullvad_setup.rsc
# Edit ONLY the variables in the section below.
# If a text value contains  $  "  or  \  escape it with a backslash.
# =====================================================================

# ------------------------- USER VARIABLES ----------------------------

# --- Mullvad WireGuard ---
:local mvPrivateKey   "PASTE_INTERFACE_PRIVATE_KEY_HERE"
:local mvServerPubKey "PASTE_SERVER_PUBLIC_KEY_HERE"
:local mvEndpointIp   "0.0.0.0"
:local mvEndpointPort 51820
:local mvWgAddress    "10.0.0.2/32"
:local mvDns          "10.64.0.1"

# --- PPPoE (interface is always created; disabled if usePppoe=false) ---
:local usePppoe       false
:local pppoeUser      "username"
:local pppoePass      "password"

# --- Static WAN IP on ether1 (nothing is created if useStatic=false) ---
:local useStatic      false
:local staticIp       "203.0.113.10/24"
:local staticGw       "203.0.113.1"

# --- Wi-Fi ---
:local ssid2g         "WiFi-2G"
:local ssid5g         "WiFi-5G"
:local wifiPass       "ChangeMe1234"
:local wifiCountry    "united kingdom"

# ----------------------- END OF USER VARIABLES -----------------------


# ------------------------- SANITY CHECKS -----------------------------
:if ([:len $mvPrivateKey] != 44 || [:len $mvServerPubKey] != 44) do={
    :error "Mullvad keys must be 44 characters (base64). Edit the variables."
}
:if ($mvEndpointIp = "0.0.0.0") do={
    :error "Set mvEndpointIp."
}
:if ([:len $wifiPass] < 8) do={
    :error "Wi-Fi password must be at least 8 characters."
}
:if ([:len [/interface wireguard find name="wg-mullvad"]] > 0) do={
    :error "wg-mullvad already exists - script was probably applied already."
}

:local pppoeDisabled "yes"
:if ($usePppoe) do={ :set pppoeDisabled "no" }


# ------------------------- WIREGUARD ---------------------------------
/interface wireguard
add name=wg-mullvad private-key=$mvPrivateKey

/interface wireguard peers
add interface=wg-mullvad name=peer-mullvad public-key=$mvServerPubKey \
    endpoint-address=$mvEndpointIp endpoint-port=$mvEndpointPort \
    allowed-address=0.0.0.0/0,::/0 persistent-keepalive=15s

/ip address
add address=$mvWgAddress interface=wg-mullvad comment="Mullvad tunnel address"


# ------------------------- PPPOE (distance 1) ------------------------
/interface pppoe-client
add name=pppoe-out1 interface=ether1 user=$pppoeUser password=$pppoePass \
    add-default-route=yes default-route-distance=1 keepalive-timeout=60 \
    disabled=$pppoeDisabled comment="PPPoE WAN"


# ------------------------- STATIC WAN (distance 2) -------------------
:if ($useStatic) do={
    /ip address add address=$staticIp interface=ether1 comment="static WAN"
    /ip route add gateway=$staticGw distance=2 comment="static WAN gateway"
}


# ------------------------- DHCP CLIENT (distance 3) ------------------
:if ([:len [/ip dhcp-client find interface=ether1]] = 0) do={
    /ip dhcp-client add interface=ether1 default-route-distance=3 \
        use-peer-dns=no use-peer-ntp=no comment="defconf"
} else={
    /ip dhcp-client set [find interface=ether1] default-route-distance=3 \
        use-peer-dns=no use-peer-ntp=no
}


# ------------------------- INTERFACE LISTS ---------------------------
/interface list member
add interface=wg-mullvad list=WAN
add interface=pppoe-out1 list=WAN


# ------------------------- DNS / DHCP SERVER -------------------------
/ip dns
set servers=8.8.8.8,8.8.4.4 cache-size=4096KiB cache-max-ttl=15m \
    allow-remote-requests=no

# Google DNS is included temporarily for testing - remove it after verifying:
#   /ip dhcp-server network set [find address=192.168.88.0/24] dns-server=<mvDns>
:if ([:len [/ip dhcp-server network find address=192.168.88.0/24]] > 0) do={
    /ip dhcp-server network set [find address=192.168.88.0/24] dns-server=8.8.8.8,8.8.4.4,$mvDns
}


# ------------------------- IPV6 OFF (avoid leaks) --------------------
/ipv6 settings
set disable-ipv6=yes


# ------------------------- FIREWALL ----------------------------------
/ip firewall mangle
add action=change-mss chain=forward new-mss=1380 out-interface=wg-mullvad \
    protocol=tcp tcp-flags=syn tcp-mss=1381-65535 comment="Mullvad MSS clamp"

# Redundant kill switch, just in case: lookup-only-in-table in the routing
# rule already acts as a kill switch by itself. Disabled by default for
# testing - enable later with:
#   /ip firewall filter enable [find comment~"Redundant kill switch"]
/ip firewall filter
add action=drop chain=forward in-interface-list=LAN out-interface=ether1 \
    disabled=yes comment="Redundant kill switch: LAN not out ether1"
add action=drop chain=forward in-interface-list=LAN out-interface=pppoe-out1 \
    disabled=yes comment="Redundant kill switch: LAN not out pppoe"


# ------------------------- POLICY ROUTING ----------------------------
/routing table
add name=to_mullvad fib

/ip route
add dst-address=0.0.0.0/0 gateway=wg-mullvad routing-table=to_mullvad \
    comment="Mullvad default route"

/routing rule
# Optional: uncomment if the router becomes unreachable from the LAN
# add action=lookup dst-address=192.168.88.0/24 table=main
# Disabled by default for testing: first test with a single host, e.g.
#   /routing rule add action=lookup-only-in-table src-address=192.168.88.X/32 table=to_mullvad
# then remove the test rule and enable this one with:
#   /routing rule enable [find comment="Mullvad: LAN via tunnel"]
add action=lookup-only-in-table src-address=192.168.88.0/24 table=to_mullvad \
    disabled=yes comment="Mullvad: LAN via tunnel"


# ------------------------- WI-FI (applied last: may drop WLAN clients)
/interface wireless security-profiles
set [find default=yes] mode=dynamic-keys authentication-types=wpa-psk,wpa2-psk \
    wpa-pre-shared-key=$wifiPass wpa2-pre-shared-key=$wifiPass

/interface wireless
set [find default-name=wlan1] disabled=no mode=ap-bridge band=2ghz-g/n \
    channel-width=20/40mhz-XX frequency=auto ssid=$ssid2g \
    country=$wifiCountry distance=indoors installation=indoor \
    hw-protection-mode=cts-to-self wireless-protocol=802.11 wps-mode=disabled
set [find default-name=wlan2] disabled=no mode=ap-bridge band=5ghz-n/ac \
    channel-width=20/40/80mhz-XXXX frequency=auto ssid=$ssid5g \
    country=$wifiCountry distance=indoors installation=indoor \
    hw-protection-mode=cts-to-self skip-dfs-channels=all \
    wireless-protocol=802.11 wps-mode=disabled

:put "Mullvad setup applied."
