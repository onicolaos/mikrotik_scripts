# script checks if there is an update avalible and installs it or does a system reboot. can be run daily at early morning or late evening
/system package update
check-for-updates once
:delay 3s;
:if ( [get status] = "New version is available") do={ install } else={ /system reboot }
