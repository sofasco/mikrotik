# 🚀 Panduan Lengkap Konfigurasi MikroTik (LAN + Wireless + Security)

Dokumentasi ini berisi langkah-langkah konfigurasi **MikroTik RouterOS** yang komprehensif agar router siap digunakan dalam lingkungan **LAN** maupun **Wireless (WiFi)**.  
Konfigurasi mencakup **IP Addressing, NAT, DHCP, DNS, Wireless, User Management, Firewall, hingga Keamanan dasar**.

Semua konfigurasi dilakukan lewat **CLI (Command Line Interface)** menggunakan **Winbox (New Terminal)**, **SSH**, atau **Console**.

---

## 📌 Daftar Isi
1. [Login ke MikroTik](#-1-login-ke-mikrotik)
2. [Reset Konfigurasi Default](#-2-reset-konfigurasi-default)
3. [Konfigurasi Interface](#-3-konfigurasi-interface)
4. [Konfigurasi IP Address](#-4-konfigurasi-ip-address)
5. [Routing & Gateway ISP](#-5-routing--gateway-isp)
6. [DNS Configuration](#-6-dns-configuration)
7. [NAT (Internet Sharing)](#-7-nat-internet-sharing)
8. [DHCP Server untuk LAN](#-8-dhcp-server-untuk-lan)
9. [Konfigurasi Wireless (WiFi)](#-9-konfigurasi-wireless-wifi)
10. [Firewall Rules Dasar](#-10-firewall-rules-dasar)
11. [Manajemen User MikroTik](#-11-manajemen-user-mikrotik)
12. [Monitoring & Tools](#-12-monitoring--tools)
13. [Verifikasi Konfigurasi](#-13-verifikasi-konfigurasi)
14. [Hasil Akhir](#-14-hasil-akhir)
15. [Best Practices & Security](#-15-best-practices--security)

---

## 🔑 1. Login ke MikroTik
Default akses:
- IP default: `192.168.88.1`
- User: `admin`
- Password: _(kosong)_

Login via SSH:
```bash
ssh admin@192.168.88.1
```

---

## ♻️ 2. Reset Konfigurasi Default
Agar mulai dari konfigurasi bersih:
```bash
/system reset-configuration no-defaults=yes skip-backup=yes
```

---

## 🖧 3. Konfigurasi Interface
Beri nama interface agar mudah dikenali:
```bash
/interface ethernet set [ find default-name=ether1 ] name=ether1-WAN
/interface ethernet set [ find default-name=ether2 ] name=ether2-LAN
```

---

## 🌐 4. Konfigurasi IP Address

### IP LAN
```bash
/ip address add address=192.168.10.1/24 interface=ether2-LAN comment="LAN Gateway"
```

### IP WAN (dari ISP)
```bash
/ip address add address=192.168.1.2/24 interface=ether1-WAN comment="WAN ISP"
```

---

## 🧭 5. Routing & Gateway ISP
Tambahkan default route ke gateway ISP:
```bash
/ip route add gateway=192.168.1.1
```

---

## 📡 6. DNS Configuration
Gunakan DNS publik (Google, Cloudflare):
```bash
/ip dns set servers=8.8.8.8,1.1.1.1 allow-remote-requests=yes
```

---

## 🔥 7. NAT (Internet Sharing)
Aktifkan NAT agar semua client bisa keluar ke internet:
```bash
/ip firewall nat add chain=srcnat out-interface=ether1-WAN action=masquerade comment="NAT ISP"
```

---

## 📦 8. DHCP Server untuk LAN

### Pool IP
```bash
/ip pool add name=dhcp_pool1 ranges=192.168.10.10-192.168.10.100
```

### DHCP Network
```bash
/ip dhcp-server network add address=192.168.10.0/24 gateway=192.168.10.1 dns-server=8.8.8.8,1.1.1.1
```

### DHCP Server
```bash
/ip dhcp-server add name=dhcp1 interface=ether2-LAN address-pool=dhcp_pool1 lease-time=1d
```

---

## 📶 9. Konfigurasi Wireless (WiFi)

### Set SSID
```bash
/interface wireless set wlan1 ssid="MikroTik-WiFi" mode=ap-bridge frequency=auto band=2ghz-b/g/n
```

### Security Profile
```bash
/interface wireless security-profiles add name=wpa2 authentication-types=wpa2-psk wpa2-pre-shared-key=PasswordWiFi
/interface wireless set wlan1 security-profile=wpa2
```

### Enable WiFi
```bash
/interface wireless enable wlan1
```

---

## 🛡️ 10. Firewall Rules Dasar

### Block akses router dari luar (WAN)
```bash
/ip firewall filter add chain=input in-interface=ether1-WAN action=drop comment="Drop all input from WAN"
```

### Allow LAN akses router
```bash
/ip firewall filter add chain=input in-interface=ether2-LAN action=accept comment="Allow LAN access to router"
```

### Allow Established & Related
```bash
/ip firewall filter add chain=input connection-state=established,related action=accept
```

### Drop Invalid
```bash
/ip firewall filter add chain=input connection-state=invalid action=drop
```

---

## 👤 11. Manajemen User MikroTik

### Tambah User Read-Only
```bash
/user add name=teknisi password=teknisi123 group=read comment="User Monitoring"
```

### Tambah User Admin
```bash
/user add name=admin2 password=admin123 group=full comment="Admin Tambahan"
```

### Disable Admin Default (opsional)
```bash
/user disable admin
```

---

## 📊 12. Monitoring & Tools

### Cek trafik interface
```bash
/interface monitor-traffic ether1-WAN
```

### Cek log
```bash
/log print
```

### Ping test ke internet
```bash
/ping 8.8.8.8
```

---

## ✅ 13. Verifikasi Konfigurasi

- IP Address:
```bash
/ip address print
```

- Routing:
```bash
/ip route print
```

- DHCP Server:
```bash
/ip dhcp-server print
```

- Wireless:
```bash
/interface wireless print
```

- Firewall:
```bash
/ip firewall filter print
```

---

## 🎯 14. Hasil Akhir
- Client **LAN** mendapat IP otomatis (`192.168.10.x`) via DHCP.  
- Client **WiFi** bisa konek ke SSID `MikroTik-WiFi` dengan password `PasswordWiFi`.  
- Semua client bisa akses internet via NAT.  
- Router aman dari akses WAN (firewall aktif).  
- User tambahan tersedia (`teknisi`, `admin2`).  

---

## 🔒 15. Best Practices & Security
- Ganti password default `admin`, atau disable user admin.  
- Gunakan group `read` untuk teknisi monitoring, `full` hanya untuk admin.  
- Aktifkan firewall untuk membatasi akses dari luar.  
- Gunakan **VPN** jika ingin remote access ke MikroTik.  
- Backup konfigurasi sebelum melakukan perubahan besar:
```bash
/export file=backup-config
```

---

✍️ **Dokumentasi ini siap dipush ke GitHub sebagai panduan konfigurasi MikroTik untuk jaringan LAN + Wireless yang aman dan stabil.**
