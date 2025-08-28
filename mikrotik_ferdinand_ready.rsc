# READY-TO-PASTE RouterOS script (idempotent + backup)
# Purpose: Configure WAN (DHCP), LAN (bridge + DHCP), and WiFi SSID default "Ferdinand" with PSK default "12345678".
# Edit variables in the CONFIGURATION block if you need different names/passwords.

# --- CONFIGURATION (edit values below if necessary)
:local WAN_IF "ether1"
:local LAN_PORT "ether2"
:local BRIDGE_NAME "bridge-LAN"
:local LAN_GW "192.168.10.1"
:local LAN_NET "192.168.10.0/24"
:local DHCP_POOL_START "192.168.10.10"
:local DHCP_POOL_END "192.168.10.200"
:local DNS_SERVERS "8.8.8.8,1.1.1.1"
:local WIFI_IF "wlan1"
:local WIFI_SSID "Ferdinand"
:local WIFI_PSK "12345678"
:local SEC_PROFILE "sec-ferdinand"

# --- create a timestamped export backup before changes
:local ts [/system clock get date]
:local fname ("backup-before-apply-" . [/system identity get name] . "-" . [:tonum [/system resource get uptime]] . ".rsc")
/export file=$fname
:put ("Exported current config to file: "$fname)

# --- helper: safe add (only create object if not exists)

# 1) Create bridge and add LAN port
:if ([:len [/interface bridge find name=$BRIDGE_NAME]] = 0) do={
	/interface bridge add name=$BRIDGE_NAME
	:put ("Created bridge: "$BRIDGE_NAME)
} else={:put ("Bridge exists: "$BRIDGE_NAME)}

:local brPort [/interface bridge port find interface=$LAN_PORT and bridge=$BRIDGE_NAME]
:if ($brPort = "") do={
	/interface bridge port add bridge=$BRIDGE_NAME interface=$LAN_PORT
	:put ("Added LAN port "$LAN_PORT" to "$BRIDGE_NAME)
} else={:put ($LAN_PORT" already in bridge")}

# 2) Assign LAN IP if missing
:if ([:len [/ip address find interface=$BRIDGE_NAME]] = 0) do={
	/ip address add address=($LAN_GW "/24") interface=$BRIDGE_NAME comment="LAN Gateway"
	:put ("Assigned LAN gateway: "$LAN_GW)
} else={:put "LAN address already present"}

# 3) DHCP pool and server
:if ([:len [/ip pool find name=dhcp_pool1]] = 0) do={/ip pool add name=dhcp_pool1 ranges=($DHCP_POOL_START..$DHCP_POOL_END); :put "Created dhcp_pool1"} else={:put "dhcp_pool1 exists"}

:if ([:len [/ip dhcp-server find name=dhcp1]] = 0) do={
	/ip dhcp-server add name=dhcp1 interface=$BRIDGE_NAME address-pool=dhcp_pool1 lease-time=1d disabled=no
	/ip dhcp-server network add address=$LAN_NET gateway=$LAN_GW dns-server=$DNS_SERVERS
	:put "Created DHCP server dhcp1"
} else={:put "DHCP server dhcp1 exists"}

# 4) WAN: DHCP client
:if ([:len [/ip dhcp-client find interface=$WAN_IF]] = 0) do={
	/ip dhcp-client add interface=$WAN_IF disabled=no use-peer-dns=yes use-peer-ntp=yes
	:put ("DHCP client added on "$WAN_IF)
} else={:put "DHCP client already present on "$WAN_IF}

# wait briefly for DHCP to assign IP and route (up to ~30s)
:local tries 0
:while ($tries < 6) do={
	:delay 5s
	:set tries ($tries + 1)
	:if ([:len [/ip address find interface=$WAN_IF]] > 0) do={:break}
}

# if no default route present, attempt to add using DHCP gateway (best-effort)
:if ([:len [/ip route find dst-address=0.0.0.0/0]] = 0) do={
	:local gw [/ip dhcp-client get [find interface=$WAN_IF] gateway]
	:if ($gw != "") do={/ip route add dst-address=0.0.0.0/0 gateway=$gw; :put ("Added default route via DHCP gateway: "$gw)} else={:put "No default route found and no DHCP gateway available yet"}
}

# 5) NAT: add masquerade for outbound
:local natFound [/ip firewall nat find chain=srcnat out-interface=$WAN_IF action=masquerade]
:if ($natFound = "") do={/ip firewall nat add chain=srcnat out-interface=$WAN_IF action=masquerade comment="NAT WAN"; :put "Added masquerade for $WAN_IF"} else={:put "Masquerade already exists for $WAN_IF"}

# 6) Basic firewall (idempotent additions)
:local rule
:if ([:len [/ip firewall filter find chain=input connection-state=established,related]] = 0) do={/ip firewall filter add chain=input connection-state=established,related action=accept comment="accept established"}
:if ([:len [/ip firewall filter find chain=input connection-state=invalid]] = 0) do={/ip firewall filter add chain=input connection-state=invalid action=drop comment="drop invalid"}
:if ([:len [/ip firewall filter find chain=input in-interface=$BRIDGE_NAME]] = 0) do={/ip firewall filter add chain=input in-interface=$BRIDGE_NAME action=accept comment="allow LAN to router"}
:if ([:len [/ip firewall filter find chain=input in-interface=$WAN_IF]] = 0) do={/ip firewall filter add chain=input in-interface=$WAN_IF action=drop comment="drop input from WAN"}
:if ([:len [/ip firewall filter find chain=forward connection-state=established,related]] = 0) do={/ip firewall filter add chain=forward connection-state=established,related action=accept comment="forward established"}
:if ([:len [/ip firewall filter find chain=forward connection-state=invalid]] = 0) do={/ip firewall filter add chain=forward connection-state=invalid action=drop comment="forward drop invalid"}
:if ([:len [/ip firewall filter find chain=forward in-interface=$BRIDGE_NAME out-interface=$WAN_IF]] = 0) do={/ip firewall filter add chain=forward in-interface=$BRIDGE_NAME out-interface=$WAN_IF action=accept comment="LAN to WAN"}
:if ([:len [/ip firewall filter find chain=forward]] = 0) do={/ip firewall filter add chain=forward action=drop comment="drop other forward"}

# 7) Wireless: create security profile and assign to wifi interface
:if ([:len [/interface wireless security-profiles find name=$SEC_PROFILE]] = 0) do={
	/interface wireless security-profiles add name=$SEC_PROFILE authentication-types=wpa2-psk mode=dynamic-keys wpa2-pre-shared-key=$WIFI_PSK
	:put ("Created wireless security profile: "$SEC_PROFILE)
} else={:put ("Security profile exists: "$SEC_PROFILE)}

:if ([:len [/interface wireless find name=$WIFI_IF]] > 0) do={
	/interface wireless set $WIFI_IF mode=ap-bridge ssid=$WIFI_SSID security-profile=$SEC_PROFILE disabled=no
	:put ("Configured wireless: SSID=".$WIFI_SSID)
	:local wlanBridgePort [/interface bridge port find interface=$WIFI_IF and bridge=$BRIDGE_NAME]
	:if ($wlanBridgePort = "") do={/interface bridge port add bridge=$BRIDGE_NAME interface=$WIFI_IF; :put ("Added "$WIFI_IF" to "$BRIDGE_NAME)} else={:put ($WIFI_IF" already in bridge")}
} else={:put ("Wireless interface not found: "$WIFI_IF)}

# 8) DNS
:if ([:len [/ip dns get servers]] = 0) do={/ip dns set servers=$DNS_SERVERS allow-remote-requests=yes}

# Final verification list
:put "--- APPLY COMPLETE ---"
:put "/ip address print"
:put "/ip route print"
:put "/ip dhcp-client print"
:put "/ip dhcp-server lease print"
:put "/ip firewall nat print"
:put "/interface wireless print"
:put "Connect a client to SSID '$WIFI_SSID' with password '$WIFI_PSK' and verify internet."
