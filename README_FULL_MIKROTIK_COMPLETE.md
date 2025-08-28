# 🚀 README LENGKAP: Konfigurasi MikroTik (Siap Pakai, Troubleshooting & Hardening)

Dokumentasi ini adalah versi lengkap, siap pakai, dan praktis dari panduan MikroTik Anda. Saya menambahkan langkah-langkah yang sering terlewat, pemeriksaan troubleshooting untuk masalah seperti "No route to host" (ICMP gagal) dan kasus "setting sandi WAN/SSID tidak muncul", serta konfigurasi yang aman untuk produksi (LAN + WAN + WiFi).

Panduan ini menggunakan CLI RouterOS (Winbox terminal / SSH / Console). Pastikan Anda memiliki akses fisik atau remote yang aman sebelum mengubah konfigurasi.

---

## Ringkasan cepat (apa yang dilakukan panduan ini)
- Menetapkan nama interface dan IP (WAN + LAN)
- Mengonfigurasi DHCP client untuk WAN (atau PPPoE) dan DHCP server untuk LAN
- Menambahkan default route dan pengecekan masalah routing
- Men-setup NAT (masquerade) untuk koneksi internet
- Men-setup Wireless (SSID + WPA2/WPA3) dengan security profile yang benar
- Menambahkan firewall rules (INPUT/FORWARD/OUTPUT) yang aman
- Menyediakan debugging commands untuk "No route to host" dan untuk masalah password WiFi/WAN
- Menyediakan backup, export config, dan best practices untuk keamanan

---

## Checklist sebelum mulai
- Pastikan firmware RouterOS sudah update (disarankan 7.x terbaru).
- Siapkan akses fisik/console untuk recovery.
- Ketahui interface fisik: ether1 (WAN), ether2..etherN (LAN) atau penamaan lain.
- Jika perangkat wireless (wlan1) aktif, pastikan driver/board support RouterOS wireless.

---

## 1) Reset bersih (opsional)
Jika ingin memulai dari nol:

```bash
/system reset-configuration no-defaults=yes skip-backup=yes
```

Perhatian: perintah ini akan menghapus seluruh konfigurasi.

---

## 2) Penamaan interface (buat jelas)
Misal: ether1 = WAN, ether2 = LAN

```bash
/interface ethernet
set [ find default-name=ether1 ] name=ether1-WAN
set [ find default-name=ether2 ] name=ether2-LAN
# jika ada bridge: create bridge and add LAN ports
/interface bridge add name=bridge-LAN
/interface bridge port add bridge=bridge-LAN interface=ether2-LAN
# repeat for other LAN ports (ether3, ether4) if needed
```

Jika Anda menggunakan bridge untuk WiFi + LAN, tambahkan interface wireless ke bridge nanti.

---

## 3) WAN configuration (DHCP client atau PPPoE)

### A. DHCP client (umum untuk modem/ISP yang memberi IP dinamis)

```bash
/ip dhcp-client add interface=ether1-WAN disabled=no use-peer-dns=yes use-peer-ntp=yes
```

Setelah menambahkan, periksa:
```bash
/ip dhcp-client print
/ip address print
/ip route print
```

Jika client berhasil, Anda akan melihat alamat IP di `ip address print` dan biasanya gateway ditambahkan otomatis di `ip route print`.

Jika tidak ada default route, tambahkan manual (lihat Troubleshooting di bawah).

### B. PPPoE (jika ISP memerlukan)

```bash
/interface pppoe-client add name=pppoe-out1 interface=ether1-WAN user="isp_user" password="isp_pass" use-peer-dns=yes add-default-route=yes disabled=no
```

Periksa status:
```bash
/interface pppoe-client print
/ip address print
/ip route print
```

---

## 4) IP LAN & DHCP Server

Contoh: LAN network 192.168.10.0/24

```bash
/ip address add address=192.168.10.1/24 interface=bridge-LAN comment="LAN Gateway"
/ip pool add name=dhcp_pool1 ranges=192.168.10.10-192.168.10.200
/ip dhcp-server network add address=192.168.10.0/24 gateway=192.168.10.1 dns-server=8.8.8.8,1.1.1.1
/ip dhcp-server add name=dhcp1 interface=bridge-LAN address-pool=dhcp_pool1 lease-time=1d disabled=no
```

Periksa:
```bash
/ip dhcp-server print
/ip dhcp-server lease print
```

---

## 5) NAT (Masquerade) — Internet Sharing

Pastikan NAT hanya pada out-interface WAN (pppoe-out1 atau ether1-WAN)

```bash
/ip firewall nat add chain=srcnat out-interface=ether1-WAN action=masquerade comment="NAT WAN"
# Jika menggunakan pppoe
#/ip firewall nat add chain=srcnat out-interface=pppoe-out1 action=masquerade comment="NAT PPPoE"
```

Periksa:
```bash
/ip firewall nat print
```

---

## 6) Firewall dasar (INPUT & FORWARD)

Aturan dasar (urutan penting):

- Terima koneksi established,related
- Tolak koneksi invalid
- Terima dari LAN ke router (administration)
- Tolak semua input dari WAN
- Untuk FORWARD: biarkan established/related dan NATed traffic

```bash
/ip firewall filter
# accept established/related
add chain=input connection-state=established,related action=accept comment="accept established"
# drop invalid
add chain=input connection-state=invalid action=drop comment="drop invalid"
# allow from LAN to router (manage router)
add chain=input in-interface=bridge-LAN action=accept comment="allow LAN to router"
# drop all from WAN to router
add chain=input in-interface=ether1-WAN action=drop comment="drop input from WAN"

# FORWARD rules for client traffic
add chain=forward connection-state=established,related action=accept comment="forward established"
add chain=forward connection-state=invalid action=drop comment="forward drop invalid"
# allow LAN->WAN
add chain=forward in-interface=bridge-LAN out-interface=ether1-WAN action=accept comment="LAN to WAN"
# drop other forward by default
add chain=forward action=drop comment="drop other forward"
```

Notes:
- Aturan `input` yang menerima LAN ke router penting agar Anda bisa mengelola router dari LAN.
- Jika Anda butuh akses SSH/Winbox dari WAN, jangan buka kecuali Anda tahu risikonya — gunakan firewall rules lebih spesifik atau IP whitelist.

---

## 7) Wireless (WiFi) — SSID & WPA2/WPA3 setup (jangan lupa security-profile!)

Jika perangkat Anda support wireless, langkah umum:

1. Pastikan `regulatory domain` / country diset (untuk kepatuhan freq):
```bash
/interface wireless set country=your_country_code wlan1
# contoh: set country=id (Indonesia)
```

2. Buat security profile (WPA2/WPA3 jika tersedia):
```bash
/interface wireless security-profiles
add name=sec-wpa2 authentication-types=wpa2-psk mode=dynamic-keys wpa2-pre-shared-key="StrongPassword123"
# Untuk WPA3 (jika supported): authentication-types=wpa3
```

3. Set SSID dan hubungkan security profile ke interface wlan1; jika menggunakan bridge, tambahkan wlan1 ke bridge-LAN

```bash
/interface wireless set wlan1 mode=ap-bridge ssid="MikroTik-WiFi" band=2ghz-b/g/n frequency=auto disabled=no security-profile=sec-wpa2
/interface bridge port add bridge=bridge-LAN interface=wlan1
```

Periksa security-profile terpasang:
```bash
/interface wireless security-profiles print
/interface wireless print
```

Penting: jika Anda *melaporkan WiFi tidak memiliki password* padahal sudah diset, periksa:
- Apakah security-profile benar ter-assign ke `wlan1`?
- Apakah mode `mode=ap-bridge` dan bukan `bridge` atau `station`?
- Apakah ada lebih dari satu SSID virtual tanpa password (bisa menggunakan interface wireless virtual)?
- Apakah device client menampilkan SSID yang benar? (restart wifi pada client)

Jika `wlan1` tidak menunjukkan password di UI client, coba reset security-profile dan set ulang:
```bash
/interface wireless security-profiles set [find name=sec-wpa2] wpa2-pre-shared-key="NewPassword!"
/interface wireless set wlan1 security-profile=sec-wpa2
/interface wireless disable wlan1; /interface wireless enable wlan1
```

Catatan tentang karakter spesial di password: jika password mengandung `"` atau `\` atau karakter shell, pastikan meng-escape atau gunakan single quotes di Winbox terminal.

---

## 8) DNS

```bash
/ip dns set servers=8.8.8.8,1.1.1.1 allow-remote-requests=yes
```

Periksa resolusi:
```bash
/ping google.com
/tool dns-update print
```

---

## 9) Routing: "No route to host" troubleshooting
Masalah "No route to host" biasanya terjadi karena:
1. Tidak ada default gateway (no default route)
2. Firewall menolak ICMP atau block forward
3. DNS resolving gagal (tampak seperti no route ketika sebenarnya hostname tidak resolve)
4. Physical link down (cable) atau wrong interface

Langkah pengecekan urut:

1) Cek `ip address`
```bash
/ip address print
```
Pastikan WAN interface memiliki IP.

2) Cek default route
```bash
/ip route print
```
Anda harus melihat route dst-address=0.0.0.0/0 melalui gateway (mis: 192.168.1.1 atau pppoe-out1)

Jika tidak ada default route, tambahkan manual (DHCP client atau PPPoE biasanya menambahkannya)
```bash
# contoh manual
/ip route add dst-address=0.0.0.0/0 gateway=192.168.1.1 distance=1
```

3) Ping gateway dari router
```bash
/ping 192.168.1.1
```
Jika ping gateway gagal, cek koneksi fisik dan apakah alamat gateway benar.

4) Cek firewall drop counters untuk INPUT & FORWARD
```bash
/ip firewall filter print stats
```
Jika banyak drop pada rule yang menolak, periksa aturan yang menolak traffic penting (ICMP, DNS, etc.). Anda mungkin perlu `accept` ICMP dari LAN dan accept established/related.

5) Cek NAT & masquerade
Jika client tidak bisa ping host eksternal sementara router bisa, periksa NAT. Pastikan rule srcnat masquerade ada dan outbound interface benar.

6) Cek DNS separately
```bash
/tool resolve google.com
```
Jika resolve gagal, periksa `ip dns` config dan coba ping IP langsung `ping 8.8.8.8`.

7) Traceroute dari router
```bash
/tool traceroute 8.8.8.8
```
Lihat di mana tracert berhenti.

---

## 10) Mengatasi kasus "SSID shows no password" di client
Penyebab umum:
- Security profile tidak diassign ke interface
- SSID broadcasting ada dua (satu open, satu secure)
- Mode wireless salah (station vs ap-bridge)
- Perangkat client cached previous open network

Perbaikan langkah demi langkah:
1. Periksa security-profile
```bash
/interface wireless security-profiles print
/interface wireless print
```
2. Pastikan `wlan1` mode=ap-bridge dan security-profile menunjuk ke profile dengan pre-shared-key
3. Restart wlan1
```bash
/interface wireless disable wlan1
/interface wireless enable wlan1
```
4. Hapus SSID yang tidak perlu (virtual interfaces)
```bash
/interface wireless remove [find ssid="OldOpenSSID"]
```
5. Pastikan client forget network lalu reconnect ke SSID yang benar.

---

## 11) Keamanan tambahan & hardening
- Ganti default admin password
```bash
/user set admin password="VeryStrongAdminPassword"
```
- Tambah user dengan role read untuk teknisi
```bash
/user add name=teknisi password=teknisiStrong group=read
```
- Disable default admin if you created new admin
```bash
/user disable admin
```
- Batasi Winbox/SSH akses hanya dari LAN (jika remote access diperlukan gunakan VPN)
```bash
/ip service set winbox address=192.168.10.0/24
/ip service set ssh address=192.168.10.0/24
```
- Aktifkan firewall logging hanya pada rule tertentu saat debugging, lalu matikan logging production.

---

## 12) Backup & Export
Selalu backup konfigurasi sebelum dan sesudah perubahan besar.

```bash
/export file=backup-config
/file print
```
Unduh file backup dari Files menu di Winbox atau via FTP.

---

## 13) Example full script (copy-paste) — adapt values before running
**CATATAN: ubah `isp_user`, `isp_pass`, `StrongPassword123`, `YourCountryCode` sesuai kebutuhan**

```bash
# rename interfaces
/interface ethernet set [ find default-name=ether1 ] name=ether1-WAN
/interface ethernet set [ find default-name=ether2 ] name=ether2-LAN

# create bridge for LAN
/interface bridge add name=bridge-LAN
/interface bridge port add bridge=bridge-LAN interface=ether2-LAN

# LAN IP
/ip address add address=192.168.10.1/24 interface=bridge-LAN comment="LAN Gateway"

# DHCP pool and server
/ip pool add name=dhcp_pool1 ranges=192.168.10.10-192.168.10.200
/ip dhcp-server network add address=192.168.10.0/24 gateway=192.168.10.1 dns-server=8.8.8.8,1.1.1.1
/ip dhcp-server add name=dhcp1 interface=bridge-LAN address-pool=dhcp_pool1 lease-time=1d disabled=no

# DHCP client on WAN (or PPPoE instead)
/ip dhcp-client add interface=ether1-WAN disabled=no use-peer-dns=yes use-peer-ntp=yes

# NAT
/ip firewall nat add chain=srcnat out-interface=ether1-WAN action=masquerade comment="NAT WAN"

# Firewall basic
/ip firewall filter add chain=input connection-state=established,related action=accept
/ip firewall filter add chain=input connection-state=invalid action=drop
/ip firewall filter add chain=input in-interface=bridge-LAN action=accept
/ip firewall filter add chain=input in-interface=ether1-WAN action=drop
/ip firewall filter add chain=forward connection-state=established,related action=accept
/ip firewall filter add chain=forward connection-state=invalid action=drop
/ip firewall filter add chain=forward in-interface=bridge-LAN out-interface=ether1-WAN action=accept
/ip firewall filter add chain=forward action=drop

# Wireless secure setup
/interface wireless set country=ID wlan1
/interface wireless security-profiles add name=sec-wpa2 authentication-types=wpa2-psk mode=dynamic-keys wpa2-pre-shared-key="StrongPassword123"
/interface wireless set wlan1 mode=ap-bridge ssid="MikroTik-WiFi" band=2ghz-b/g/n frequency=auto disabled=no security-profile=sec-wpa2
/interface bridge port add bridge=bridge-LAN interface=wlan1

# DNS
/ip dns set servers=8.8.8.8,1.1.1.1 allow-remote-requests=yes

# Change admin password
/user set admin password="VeryStrongAdminPassword"

# Backup
/export file=backup-config
```

---

## 14) Troubleshooting cepat (ringkas)
- Jika `ping 8.8.8.8` dari router sukses, tapi client gagal: cek NAT, masquerade dan firewall FORWARD.
- Jika `ping gateway` gagal: cek kabel/port dan IP gateway.
- Jika DHCP client tidak dapat IP: cek `ip dhcp-client print` dan lihat `status`.
- Jika SSID muncul open (no password): periksa `security-profile` dan mode `ap-bridge`.

---

## 15) FAQ singkat
Q: Kenapa saya dapat "no route to host" saat ping host eksternal?
A: Lihat section Routing & Troubleshooting (cek default route, ping gateway, traceroute).

Q: Kenapa SSID tidak meminta password?
A: Mungkin security profile tidak terpasang atau ada SSID lain yang open; periksa `interface wireless` dan `security-profiles`.

Q: Bagaimana jika saya kehilangan akses setelah konfigurasi?
A: Gunakan console fisik untuk reset atau koneksi serial, atau reset config jika perlu.

---

## 16) Referensi cepat (perintah pemeriksaan)
```bash
# IP addresses
/ip address print
# Routes
/ip route print
# Firewall
/ip firewall filter print
/ip firewall nat print
# Wireless
/interface wireless print
/interface wireless security-profiles print
# DHCP
/ip dhcp-server print
/ip dhcp-server lease print
# DHCP client
/ip dhcp-client print
# PPPoE
/interface pppoe-client print
# DNS
/ip dns print
# Traceroute
/tool traceroute 8.8.8.8
# Ping
/ping 8.8.8.8
```

---

Jika Anda ingin, saya bisa:
- Menyusun file script lengkap yang bisa di-run di terminal (perubahan batch),
- Menambahkan contoh konfigurasi untuk VLAN dan guest WiFi yang terisolasi,
- Membuat video singkat langkah-langkah Winbox/SSH.

Pilih salah satu: `script` / `vlan_guest_wifi` / `video_walkthrough` / `tidak sekarang`.

---

✍️ Dokumentasi ini dibuat lengkap agar perangkat MikroTik Anda dapat digunakan tanpa error umum. Jika ada bagian perangkat keras spesifik (model RouterBOARD), saya akan sesuaikan contoh perintahnya untuk model tersebut.
