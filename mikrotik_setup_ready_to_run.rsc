# Mikrotik Ready-to-Run Setup Script (idempotent + backup)
# Usage: edit CONFIGURATION below then paste entire file into Winbox > New Terminal or upload to Files and run /import.

# --------------------------
# CONFIGURATION - EDIT ME
# --------------------------
:local WAN_IF "ether1"            # physical interface connected to modem/ISP
:local LAN_IFS {"ether2"}        # array of LAN ports to attach to bridge (add more as needed)
:local BRIDGE_NAME "bridge-LAN"   # bridge name for LAN
:local LAN_SUBNET "192.168.10.0/24"
:local LAN_GW "192.168.10.1"
:local DHCP_RANGE_START "192.168.10.10"
:local DHCP_RANGE_END   "192.168.10.200"
:local DNS_SERVERS "8.8.8.8,1.1.1.1"
:local WAN_MODE "dhcp"           # options: dhcp | pppoe | static
# PPPoE only (if WAN_MODE=pppoe):
:local PPP_USER "isp_user"
:local PPP_PASS "isp_pass"
# STATIC only (if WAN_MODE=static):
:local STATIC_IP "203.0.113.10/24"
:local STATIC_GW "203.0.113.1"

# Wireless config
:local WIFI_IF "wlan1"            # wireless interface name (change if different)
:local WIFI_SSID "Ferdinand"      # default SSID (updated to Ferdinand)
:local WIFI_PSK  "12345678"       # default PSK (updated to 12345678)
:local WIFI_COUNTRY "ID"          # country code (ID for Indonesia)
:local WIFI_SEC_PROFILE "sec-ferdinand"

# Admin account (only change if you want to update admin password)
:local NEW_ADMIN_PASS ""

# --------------------------
# SAFETY - preview interfaces
# --------------------------
:put "-- Current interfaces: --"
/interface print
:put "\n-- Make sure the interface names above match WAN_IF and LAN_IFS variables. Edit script if they differ. --"

# Pause for 5 seconds to let user abort if wrong
:delay 5s

# Create backup/export before changes
:local fname ("backup-before-setup-" . [/system identity get name] . "-" . [:tonum [/system resource get uptime]] . ".rsc")
/export file=$fname
:put ("Exported current config to file: "$fname)

# --------------------------
# 1) Create bridge for LAN and add ports (idempotent)
# --------------------------
:if ([:len [/interface bridge find name=$BRIDGE_NAME]] = 0) do={
    /interface bridge add name=$BRIDGE_NAME
    :put ("Created bridge: "$BRIDGE_NAME)
} else={
    :put ("Bridge already exists: "$BRIDGE_NAME)
}

:foreach ifName in=$LAN_IFS do={
    :local portExists [/interface bridge port find interface=$ifName and bridge=$BRIDGE_NAME]
    :if ($portExists = "") do={
        /interface bridge port add bridge=$BRIDGE_NAME interface=$ifName
        :put ("Added "$ifName" to "$BRIDGE_NAME)
    } else={
        :put ($ifName" already in bridge")
    }
}

# --------------------------
# 2) Configure LAN IP and DHCP server
# --------------------------
:if ([:len [/ip address find interface=$BRIDGE_NAME]] = 0) do={
    /ip address add address=$LAN_GW/24 interface=$BRIDGE_NAME comment="LAN Gateway"
    :put ("Assigned LAN gateway: "$LAN_GW)
} else={
    :put "LAN address already exists on bridge"
}

# DHCP pool & server (idempotent)
:if ([:len [/ip pool find name=dhcp_pool1]] = 0) do={
    /ip pool add name=dhcp_pool1 ranges=($DHCP_RANGE_START..$DHCP_RANGE_END)
    :put "Created DHCP pool: dhcp_pool1"
}

:if ([:len [/ip dhcp-server find name=dhcp1]] = 0) do={
    /ip dhcp-server add name=dhcp1 interface=$BRIDGE_NAME address-pool=dhcp_pool1 lease-time=1d disabled=no
    /ip dhcp-server network add address=$LAN_SUBNET gateway=$LAN_GW dns-server=$DNS_SERVERS
    :put "Created DHCP server: dhcp1"
} else={
    :put "DHCP server dhcp1 already present"
}

# --------------------------
# 3) Configure WAN (default: DHCP)
# --------------------------
:put ("Configuring WAN mode: "$WAN_MODE)

:if ($WAN_MODE = "dhcp") do={
    :if ([:len [/ip dhcp-client find interface=$WAN_IF]] = 0) do={
        /ip dhcp-client add interface=$WAN_IF disabled=no use-peer-dns=yes use-peer-ntp=yes
        :put "Added DHCP client on $WAN_IF"
    } else={
        :put "DHCP client already configured on $WAN_IF"
    }
}

# PPPoE
:if ($WAN_MODE = "pppoe") do={
    :if ([:len [/interface pppoe-client find name=pppoe-out1]] = 0) do={
        /interface pppoe-client add name=pppoe-out1 interface=$WAN_IF user=$PPP_USER password=$PPP_PASS use-peer-dns=yes add-default-route=yes disabled=no
        :put "Added PPPoE client: pppoe-out1"
    } else={
        :put "pppoe-out1 already exists"
    }
}

# Static
:if ($WAN_MODE = "static") do={
    :if ([:len [/ip address find interface=$WAN_IF]] = 0) do={
        /ip address add address=$STATIC_IP interface=$WAN_IF
        /ip route add dst-address=0.0.0.0/0 gateway=$STATIC_GW
        :put "Assigned static IP $STATIC_IP and default route $STATIC_GW"
    } else={
        :put "Static IP already present on $WAN_IF"
    }
}

# --------------------------
# 4) NAT (Masquerade) on outbound
# --------------------------
:local natExists [/ip firewall nat find chain=srcnat out-interface=$WAN_IF action=masquerade]
:if ($natExists = "") do={
    /ip firewall nat add chain=srcnat out-interface=$WAN_IF action=masquerade comment="NAT WAN"
    :put "Added masquerade NAT for $WAN_IF"
} else={
    :put "Masquerade already exists for $WAN_IF"
}

# --------------------------
# 5) Basic Firewall rules (idempotent)
# --------------------------
:put "Configuring basic firewall rules"

:if ([:len [/ip firewall filter find chain=input connection-state=established,related]] = 0) do={/ip firewall filter add chain=input connection-state=established,related action=accept comment="accept established"}
:if ([:len [/ip firewall filter find chain=input connection-state=invalid]] = 0) do={/ip firewall filter add chain=input connection-state=invalid action=drop comment="drop invalid"}
:if ([:len [/ip firewall filter find chain=input in-interface=$BRIDGE_NAME]] = 0) do={/ip firewall filter add chain=input in-interface=$BRIDGE_NAME action=accept comment="allow LAN to router"}
:if ([:len [/ip firewall filter find chain=input in-interface=$WAN_IF]] = 0) do={/ip firewall filter add chain=input in-interface=$WAN_IF action=drop comment="drop input from WAN"}
:if ([:len [/ip firewall filter find chain=forward connection-state=established,related]] = 0) do={/ip firewall filter add chain=forward connection-state=established,related action=accept comment="forward established"}
:if ([:len [/ip firewall filter find chain=forward connection-state=invalid]] = 0) do={/ip firewall filter add chain=forward connection-state=invalid action=drop comment="forward drop invalid"}
:if ([:len [/ip firewall filter find chain=forward in-interface=$BRIDGE_NAME out-interface=$WAN_IF]] = 0) do={/ip firewall filter add chain=forward in-interface=$BRIDGE_NAME out-interface=$WAN_IF action=accept comment="LAN to WAN"}
:if ([:len [/ip firewall filter find chain=forward action=drop]] = 0) do={/ip firewall filter add chain=forward action=drop comment="drop other forward"}

# --------------------------
# 6) Wireless secure setup (if wlan exists)
# --------------------------
:if ([:len [/interface wireless find name=$WIFI_IF]] > 0) do={
    /interface wireless set $WIFI_IF country=$WIFI_COUNTRY
    :local spIndex [/interface wireless security-profiles find name=$WIFI_SEC_PROFILE]
    :if ($spIndex = "") do={
        /interface wireless security-profiles add name=$WIFI_SEC_PROFILE authentication-types=wpa2-psk mode=dynamic-keys wpa2-pre-shared-key=$WIFI_PSK
        :put "Created security-profile $WIFI_SEC_PROFILE"
    } else={
        :put "security-profile $WIFI_SEC_PROFILE already exists"
    }
    /interface wireless set $WIFI_IF mode=ap-bridge ssid=$WIFI_SSID frequency=auto disabled=no security-profile=$WIFI_SEC_PROFILE
    # Add wlan to bridge
    :local wlanBridge [/interface bridge port find interface=$WIFI_IF and bridge=$BRIDGE_NAME]
    :if ($wlanBridge = "") do={/interface bridge port add bridge=$BRIDGE_NAME interface=$WIFI_IF; :put ("Added "$WIFI_IF" to "$BRIDGE_NAME)} else={:put ($WIFI_IF" already in bridge")}
} else={
    :put "Wireless interface $WIFI_IF not found; skipping wireless setup"
}

# --------------------------
# 7) Admin password & services (optional)
# --------------------------
:if ($NEW_ADMIN_PASS != "") do={
    :if ([:len [/user find name=admin]] > 0) do={/user set admin password=$NEW_ADMIN_PASS; :put "Admin password updated"}
}

# Restrict Winbox/SSH to LAN only (recommended)
:local srvWinbox [/ip service find name=winbox]
:if ($srvWinbox != "") do={/ip service set winbox address=($LAN_SUBNET)}
:local srvSSH [/ip service find name=ssh]
:if ($srvSSH != "") do={/ip service set ssh address=($LAN_SUBNET)}

# --------------------------
# 8) Final verification commands to run manually (or see below)
# --------------------------
:put "Setup finished. Run verification commands below to confirm connectivity."

:put "\n--- VERIFICATION ---"
:put "/ip address print"
:put "/ip dhcp-client print"
:put "/ip route print"
:put "/ip firewall nat print"
:put "/ip dhcp-server lease print"
:put "Try: /ping 8.8.8.8 and /tool traceroute 8.8.8.8"

# End of script

# --------------------------
# Quick manual verification commands (paste these after script runs):
# --------------------------
# 1) Check WAN IP and default route:
# /ip address print
# /ip route print
# 2) Ping gateway and public IP
# /ping <gateway-ip>
# /ping 8.8.8.8
# 3) From a LAN client: renew DHCP and test internet
# (On client) ipconfig /release && ipconfig /renew  (Windows) or sudo dhclient -r && sudo dhclient
# 4) Check DHCP leases on router
# /ip dhcp-server lease print
# 5) If LAN clients still have no internet:
# - check /ip firewall nat print has masquerade for outbound
# - ensure /ip firewall filter rules allow forward established/related and LAN->WAN
# - run /tool traceroute 8.8.8.8 from router to spot where it stops
