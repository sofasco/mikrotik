# READY-TO-PASTE RouterOS script
# Purpose: Configure WAN (DHCP), LAN (ethernet bridge + DHCP), and WiFi SSID "Ferdinand" with PSK "12345678".
# PRECAUTION: Check interface names (ether1 = WAN, ether2 = LAN, wlan1 = wireless) before running.
# Paste entire content to Winbox > New Terminal or upload to Files and run /import.

# --- 1) Bridge LAN and add ethernet port (ether2)
/interface bridge add name=bridge-LAN
/interface bridge port add bridge=bridge-LAN interface=ether2

# --- 2) Assign LAN gateway IP
/ip address add address=192.168.10.1/24 interface=bridge-LAN comment="LAN Gateway Ferdinand"

# --- 3) DHCP pool and server for LAN
/ip pool add name=dhcp_pool1 ranges=192.168.10.10-192.168.10.200
/ip dhcp-server add name=dhcp1 interface=bridge-LAN address-pool=dhcp_pool1 lease-time=1d disabled=no
/ip dhcp-server network add address=192.168.10.0/24 gateway=192.168.10.1 dns-server=8.8.8.8,1.1.1.1

# --- 4) WAN - DHCP client on ether1
/ip dhcp-client add interface=ether1 disabled=no use-peer-dns=yes use-peer-ntp=yes

# --- 5) NAT (masquerade) for outbound Internet
/ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade comment="NAT WAN Ferdinand"

# --- 6) Basic firewall rules (keep management from LAN)
/ip firewall filter add chain=input connection-state=established,related action=accept comment="accept established"
/ip firewall filter add chain=input connection-state=invalid action=drop comment="drop invalid"
/ip firewall filter add chain=input in-interface=bridge-LAN action=accept comment="allow LAN to router"
/ip firewall filter add chain=input in-interface=ether1 action=drop comment="drop input from WAN"
/ip firewall filter add chain=forward connection-state=established,related action=accept comment="forward established"
/ip firewall filter add chain=forward connection-state=invalid action=drop comment="forward drop invalid"
/ip firewall filter add chain=forward in-interface=bridge-LAN out-interface=ether1 action=accept comment="LAN to WAN"
/ip firewall filter add chain=forward action=drop comment="drop other forward"

# --- 7) Wireless: set SSID Ferdinand and WPA2 PSK 12345678, add wlan1 to bridge
/interface wireless security-profiles add name=sec-ferdinand authentication-types=wpa2-psk mode=dynamic-keys wpa2-pre-shared-key="12345678"
/interface wireless set wlan1 mode=ap-bridge ssid="Ferdinand" frequency=auto disabled=no security-profile=sec-ferdinand
/interface bridge port add bridge=bridge-LAN interface=wlan1

# --- 8) DNS - allow router to answer DNS for clients
/ip dns set servers=8.8.8.8,1.1.1.1 allow-remote-requests=yes

# --- 9) Quick verification prints (run manually if desired)
:put "Run these to verify:"
:put "/ip address print"
:put "/ip route print"
:put "/ip dhcp-client print"
:put "/ip dhcp-server lease print"
:put "/ip firewall nat print"
:put "/interface wireless print"
:put "Then test: connect a client to SSID 'Ferdinand' with password '12345678' and verify internet access."

# End of script
