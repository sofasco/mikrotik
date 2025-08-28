# Mikrotik VLAN + Guest WiFi Ready-to-Run Script
# Paste this into Winbox > New Terminal or /import after uploading to Files.
# Edit variables in CONFIGURATION section first to match your hardware and network.

# --------------------------
# CONFIGURATION - edit these
# --------------------------
:local TRUNK_IF "ether2"            # physical port connected to managed switch or internal trunk
:local WAN_IF "ether1"              # WAN interface

:local VLAN_LAN_ID 10
:local VLAN_GUEST_ID 20
:local VLAN_LAN_NAME "vlan10-LAN"
:local VLAN_GUEST_NAME "vlan20-GUEST"

:local BRIDGE_LAN "bridge-LAN"      # existing LAN bridge (where main LAN hosts are)
:local BRIDGE_GUEST "bridge-GUEST"  # new bridge for guest

:local LAN_SUBNET "192.168.10.0/24"
:local LAN_GW "192.168.10.1"
:local GUEST_SUBNET "192.168.20.0/24"
:local GUEST_GW "192.168.20.1"

:local GUEST_DHCP_START "192.168.20.10"
:local GUEST_DHCP_END   "192.168.20.200"
:local DNS_SERVERS "8.8.8.8,1.1.1.1"

:local WIFI_MASTER_IF "wlan1"       # physical wireless interface
:local WIFI_GUEST_AP "guest-ap"    # virtual AP name for guest
:local WIFI_GUEST_SSID "Guest-WiFi"
:local WIFI_GUEST_PSK  "GuestPass123"   # change to strong value or set open/captive portal as desired
:local WIFI_COUNTRY "ID"

# --------------------------
# NOTES / ASSUMPTIONS
# --------------------------
# - This script creates 802.1Q VLAN interfaces on the router's trunk port ($TRUNK_IF).
# - If your device has a hardware switch (switch chip), you may need to configure switch VLANs instead (different commands).
# - The switch connected to $TRUNK_IF must be configured to carry VLAN tags (trunk) for VLAN 10 and 20.
# - The main LAN remains on VLAN 10 and guest on VLAN 20; if you don't use a managed switch and only use router ports, you can skip VLAN and just place different ports into the guest bridge.

:put "Starting VLAN + Guest WiFi setup"

# --------------------------
# 1) Create VLAN interfaces on trunk
# --------------------------
:if ([:len [/interface vlan find name=$VLAN_LAN_NAME]] = 0) do={
    /interface vlan add name=$VLAN_LAN_NAME vlan-id=$VLAN_LAN_ID interface=$TRUNK_IF
    :put ("Created VLAN interface: "$VLAN_LAN_NAME)
} else={
    :put ("VLAN interface exists: "$VLAN_LAN_NAME)
}

:if ([:len [/interface vlan find name=$VLAN_GUEST_NAME]] = 0) do={
    /interface vlan add name=$VLAN_GUEST_NAME vlan-id=$VLAN_GUEST_ID interface=$TRUNK_IF
    :put ("Created VLAN interface: "$VLAN_GUEST_NAME)
} else={
    :put ("VLAN interface exists: "$VLAN_GUEST_NAME)
}

# --------------------------
# 2) Create guest bridge and attach VLAN guest (and guest AP later)
# --------------------------
:if ([:len [/interface bridge find name=$BRIDGE_GUEST]] = 0) do={
    /interface bridge add name=$BRIDGE_GUEST
    :put ("Created bridge: "$BRIDGE_GUEST)
} else={
    :put ("Bridge already exists: "$BRIDGE_GUEST)
}

# Add VLAN guest interface to guest bridge
:local guestPort [/interface bridge port find interface=$VLAN_GUEST_NAME and bridge=$BRIDGE_GUEST]
:if ($guestPort = "") do={
    /interface bridge port add bridge=$BRIDGE_GUEST interface=$VLAN_GUEST_NAME
    :put ("Added "$VLAN_GUEST_NAME" to "$BRIDGE_GUEST)
} else={
    :put ($VLAN_GUEST_NAME" already a bridge port")
}

# --------------------------
# 3) Configure IP for guest bridge and DHCP server
# --------------------------
/ip address
:if ([:len [/ip address find interface=$BRIDGE_GUEST]] = 0) do={
    /ip address add address=$GUEST_GW/24 interface=$BRIDGE_GUEST comment="Guest Gateway"
    :put ("Assigned guest gateway: "$GUEST_GW)
} else={
    :put "Guest IP already configured"
}

/ip pool
:if ([:len [/ip pool find name=guest_pool]] = 0) do={
    /ip pool add name=guest_pool ranges=($GUEST_DHCP_START..$GUEST_DHCP_END)
    :put "Created guest DHCP pool: guest_pool"
}

/ip dhcp-server
:if ([:len [/ip dhcp-server find name=guest_dhcp]] = 0) do={
    /ip dhcp-server add name=guest_dhcp interface=$BRIDGE_GUEST address-pool=guest_pool lease-time=12h disabled=no
    /ip dhcp-server network add address=$GUEST_SUBNET gateway=$GUEST_GW dns-server=$DNS_SERVERS
    :put "Created DHCP server: guest_dhcp"
} else={
    :put "Guest DHCP server already exists"
}

# --------------------------
# 4) Set up guest wireless AP (virtual AP) and attach to guest bridge
# --------------------------
:if ([:len [/interface wireless find name=$WIFI_MASTER_IF]] > 0) do={
    :if ([:len [/interface wireless find name=$WIFI_GUEST_AP]] = 0) do={
        /interface wireless add name=$WIFI_GUEST_AP master-interface=$WIFI_MASTER_IF ssid=$WIFI_GUEST_SSID mode=ap-bridge disabled=no
        :put ("Created virtual AP: "$WIFI_GUEST_AP)
    } else={
        :put ("Virtual AP exists: "$WIFI_GUEST_AP)
    }

    # create or reuse guest security profile
    :local sp [/interface wireless security-profiles find name=sec-guest]
    :if ($sp = "") do={
        /interface wireless security-profiles add name=sec-guest authentication-types=wpa2-psk mode=dynamic-keys wpa2-pre-shared-key=$WIFI_GUEST_PSK
        :put "Created wireless security profile: sec-guest"
    } else={
        :put "Wireless security profile sec-guest exists"
    }
    /interface wireless set $WIFI_GUEST_AP security-profile=sec-guest country=$WIFI_COUNTRY

    # add guest AP to bridge
    :local apBridge [/interface bridge port find interface=$WIFI_GUEST_AP and bridge=$BRIDGE_GUEST]
    :if ($apBridge = "") do={
        /interface bridge port add bridge=$BRIDGE_GUEST interface=$WIFI_GUEST_AP
        :put ("Added "$WIFI_GUEST_AP" to "$BRIDGE_GUEST)
    } else={
        :put ($WIFI_GUEST_AP" already in bridge")
    }
} else={
    :put ("Wireless master interface not found: "$WIFI_MASTER_IF" - skipping guest AP creation")
}

# --------------------------
# 5) NAT and firewall for guest isolation
# --------------------------
# NAT for guest to internet
:local natGuest [/ip firewall nat find chain=srcnat out-interface=$WAN_IF action=masquerade]
:if ($natGuest = "") do={
    /ip firewall nat add chain=srcnat out-interface=$WAN_IF action=masquerade comment="guest_nat"
    :put "Added masquerade NAT for guest -> WAN"
} else={
    :put "Masquerade NAT already exists (may be general NAT)"
}

# Firewall: allow guest to internet, block guest->LAN
:local f1 [/ip firewall filter find chain=forward in-interface=$BRIDGE_GUEST out-interface=$WAN_IF action=accept]
:if ($f1 = "") do={
    /ip firewall filter add chain=forward in-interface=$BRIDGE_GUEST out-interface=$WAN_IF action=accept comment="guest to wan"
    :put "Allow guest -> WAN"
} else={:put "guest->WAN rule exists"}

:local f2 [/ip firewall filter find chain=forward in-interface=$BRIDGE_GUEST out-interface=$BRIDGE_LAN action=drop]
:if ($f2 = "") do={
    /ip firewall filter add chain=forward in-interface=$BRIDGE_GUEST out-interface=$BRIDGE_LAN action=drop comment="isolate guest from lan"
    :put "Block guest -> LAN"
} else={:put "guest->LAN isolation rule exists"}

# make sure established/related are allowed (global rules usually exist)
:local fER [/ip firewall filter find chain=forward connection-state=established,related action=accept]
:if ($fER = "") do={/ip firewall filter add chain=forward connection-state=established,related action=accept comment="forward established"}

# --------------------------
# 6) Helpful verification commands
# --------------------------
:put "\n--- VERIFY ---"
:put "/interface vlan print"
:put "/interface bridge print"
:put "/interface bridge port print"
:put "/ip address print"
:put "/ip dhcp-server print"
:put "/ip dhcp-server lease print"
:put "/ip firewall filter print"
:put "/ip firewall nat print"
:put "Try: /ping 8.8.8.8 from router and connect a guest client to $WIFI_GUEST_SSID"

# Reminders
:put "IMPORTANT: If you use RouterBOARD switch chip (hardware switch), adjust switch VLAN configuration instead of only creating VLAN interfaces on trunk port."
:put "If passing VLANs across a managed switch, configure the switch port connected to the router as a trunk allowing VLAN 10 and 20."

# End of script
