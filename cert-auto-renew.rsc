# --- Config ---
:local dnsName "htt.mikrotik.al"
:local thresholdDays 15

# --- Find matching cert ---
:local certId [/certificate find where name~$dnsName]

# --- Check if cert found ---
:if ([:len $certId] = 0) do={
    :log warning "[SSL] No certificate found matching ~$dnsName"
} else={

    :local cert ($certId->0)
    :local name [/certificate get $cert name]
    :local expiresAfter [/certificate get $cert expires-after]

    # Example format: "1w5d17:20:30"
    :local totalDays 0

    # Parse weeks if present
    :if ([:find $expiresAfter "w"] != nil) do={
        :local weeks [:pick $expiresAfter 0 [:find $expiresAfter "w"]]
        :set totalDays ($totalDays + ($weeks * 7))
        :set expiresAfter [:pick $expiresAfter ([:find $expiresAfter "w"] + 1) [:len $expiresAfter]]
    }

    # Parse days if present
    :if ([:find $expiresAfter "d"] != nil) do={
        :local days [:pick $expiresAfter 0 [:find $expiresAfter "d"]]
        :set totalDays ($totalDays + $days)
    }

    :log info ("[SSL] Certificate '$name' expires in $totalDays days.")

    :if ($totalDays < $thresholdDays) do={
        :log info ("[SSL] Enable firewall input rule related to WEB...")
        /ip firewall filter enable [find where chain=input action=accept comment~"WEB"]
        :log info ("[SSL] Disable any dst-nat rule related to WEB...")
        /ip firewall nat disable [find where chain=dstnat action=dst-nat comment~"WEB"]
        :log info ("[SSL] Enable WEB service if disabled...")
        :local rWWW [/ip service get [find name=www] disabled]
        :if ([/ip service get [find name=www] disabled] = true) do={ [/ip service enable [find name=www]] }
        :local AvalibleFrom [/ip service get [find name=www] address]
        /ip service set [find name=www] address="0.0.0.0/0"

        :log warning ("[SSL] Renewing certificate for $dnsName...")
        /certificate enable-ssl-certificate dns-name=$dnsName
        :delay 5

        :log info ("[SSL] Disable firewall input rule related to WEB...")
        /ip firewall filter disable [find where chain=input action=accept comment~"WEB"]
        :log info ("[SSL] Enable any dst-nat rule related to WEB...")
        /ip firewall nat enable [find where chain=dstnat action=dst-nat comment~"WEB"]
        :log info ("[SSL] Disable WEB service if it was disabled...")
        :if $rWWW do={ [/ip service disable [find name=www]] }
        /ip service set [find name=www] address=$AvalibleFrom
    } else={
        :log info ("[SSL] Certificate for $dnsName is still valid ($totalDays days left).")
    }
}
