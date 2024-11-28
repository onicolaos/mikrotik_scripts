# Enhanced MikroTik CAPsMAN Auto-Provision Script
# This script is created to address a bug in MikroTik CAPsMAN (version 7.16.2) where
# the 'reselect interval' for automatic channel selection does not function as expected.
# The script ensures access points (CAPs) reselect channels at different intervals to 
# avoid overlapping channel selection due to simultaneous scanning at startup.

# Define scheduler name and intervals
:local schedulerName "auto_provision"
:local shortInterval "00:01:15"
:local mediumInterval "00:11:15"
:local longInterval "01:11:15"

# Get the system uptime in seconds
:local uptime [/system resource get uptime]

# Set the scheduler interval based on uptime
:if ($uptime > 00:05:00 && $uptime < 02:00:00) do={
    :if ([/system scheduler get [find name=$schedulerName] interval] != $shortInterval) do={
        /system scheduler set [find name=$schedulerName] interval=$shortInterval
    }
} else={
    :if ($uptime < 08:00:00) do={
        :if ([/system scheduler get [find name=$schedulerName] interval] != $mediumInterval) do={
            /system scheduler set [find name=$schedulerName] interval=$mediumInterval
        }
    } else={
        :if ([/system scheduler get [find name=$schedulerName] interval] != $longInterval) do={
            /system scheduler set [find name=$schedulerName] interval=$longInterval
        }
    }
}

# Get the total count of CAPsMAN remote CAPs
:local apCount [/interface wifi capsman remote-cap print count-only]

# Define and initialize lastProvisionedAP variable if not set
:global lastProvisionedAP
:if ([:typeof $lastProvisionedAP] != "num" || $lastProvisionedAP >= ($apCount - 1)) do={
    :set $lastProvisionedAP 0
} else={
    :set $lastProvisionedAP ($lastProvisionedAP + 1)
}

# Provision the CAP based on the current index
/interface wifi capsman remote-cap provision $lastProvisionedAP

# Log the provisioning action
:log info ("Provisioned CAP at index: $lastProvisionedAP")

# Ensure the scheduler is always set to the short interval during initial uptime
:if ($uptime <= 00:05:00) do={
    :if ([/system scheduler get [find name=$schedulerName] interval] != $shortInterval) do={
        /system scheduler set [find name=$schedulerName] interval=$shortInterval
    }
}
