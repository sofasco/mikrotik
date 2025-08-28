# 🚀 Panduan Konfigurasi Dasar MikroTik (LAN + Wireless)

Dokumentasi ini berisi langkah konfigurasi **MikroTik RouterOS** agar siap digunakan untuk akses internet melalui **LAN** dan **Wireless (WiFi)**.  
Seluruh konfigurasi dilakukan menggunakan **CLI (Command Line Interface)**, baik melalui **Winbox (New Terminal)**, **SSH**, atau **Console langsung**.

---

## 📌 Daftar Isi
1. [Login ke MikroTik](#-1-login-ke-mikrotik)
2. [Konfigurasi IP Address](#-2-konfigurasi-ip-address-lan--wan)
3. [Konfigurasi DNS](#-3-dns-configuration)
4. [NAT (Internet Sharing)](#-4-nat-network-address-translation)
5. [DHCP Server untuk LAN](#-5-dhcp-server-lan)
6. [Konfigurasi Wireless (WiFi)](#-6-konfigurasi-wireless-wifi)
7. [Manajemen User MikroTik](#-7-manajemen-user-mikrotik)
8. [Verifikasi Konfigurasi](#-8-cek-konfigurasi)
9. [Hasil Akhir](#-9-hasil-akhir)
10. [Catatan Keamanan](#-10-catatan)

---

## 🔑 1. Login ke MikroTik
Gunakan **Winbox**, atau jika dari Linux/Mac/Windows dengan SSH:

```bash
ssh admin@192.168.88.1
```

---

## 🌐 2. Konfigurasi IP Address (LAN & WAN)

### 2.1. Tambahkan IP untuk LAN
```bash
/ip address add address=192.168.10.1/24 interface=ether2-LAN
```
- `192.168.10.1/24` → IP LAN router  
- `ether2-LAN` → port LAN (ganti sesuai kebutuhan)  

### 2.2. Tambahkan IP untuk WAN (koneksi ke modem/ISP)
```bash
/ip address add address=192.168.1.2/24 interface=ether1-WAN
/ip route add gateway=192.168.1.1
```
- `192.168.1.2/24` → IP router di sisi WAN  
- `192.168.1.1` → Gateway modem/ISP  

---

## 🧭 3. DNS Configuration
Agar client bisa melakukan resolusi domain:

```bash
/ip dns set servers=8.8.8.8,1.1.1.1 allow-remote-requests=yes
```

---

## 🔥 4. NAT (Network Address Translation)
Agar semua client LAN & WiFi bisa mengakses internet:

```bash
/ip firewall nat add chain=srcnat out-interface=ether1-WAN action=masquerade
```

---

## 📡 5. DHCP Server (LAN)

### 5.1. Buat Pool IP
```bash
/ip pool add name=dhcp_pool1 ranges=192.168.10.10-192.168.10.100
```

### 5.2. Atur Network DHCP
```bash
/ip dhcp-server network add address=192.168.10.0/24 gateway=192.168.10.1 dns-server=8.8.8.8,1.1.1.1
```

### 5.3. Aktifkan DHCP Server
```bash
/ip dhcp-server add name=dhcp1 interface=ether2-LAN address-pool=dhcp_pool1 lease-time=1d
```

---

## 📶 6. Konfigurasi Wireless (WiFi)

### 6.1. Set SSID
```bash
/interface wireless set wlan1 ssid="MikroTik-WiFi" mode=ap-bridge
```

### 6.2. Security Profile (Password WiFi)
```bash
/interface wireless security-profiles add name=wpa2 authentication-types=wpa2-psk wpa2-pre-shared-key=PasswordWiFi
/interface wireless set wlan1 security-profile=wpa2
```

### 6.3. Enable WiFi
```bash
/interface wireless enable wlan1
```

---

## 👤 7. Manajemen User MikroTik

### Tambah User Read-Only
```bash
/user add name=teknisi password=teknisi123 group=read
```

### Tambah Admin Baru
```bash
/user add name=admin2 password=admin123 group=full
```

### Cek Daftar User
```bash
/user print
```

---

## ✅ 8. Cek Konfigurasi

- **Cek IP Address**
```bash
/ip address print
```

- **Cek Routing**
```bash
/ip route print
```

- **Cek Wireless**
```bash
/interface wireless print
```

- **Cek DHCP**
```bash
/ip dhcp-server print
```

---

## 🎯 9. Hasil Akhir
- Client **LAN** mendapatkan IP otomatis via DHCP.  
- Client **WiFi** bisa konek ke SSID `MikroTik-WiFi` dengan password `PasswordWiFi`.  
- Semua device LAN & WiFi bisa akses internet.  
- User tambahan (`teknisi`, `admin2`) sudah tersedia.  

---

## 🔒 10. Catatan
- Ganti IP, SSID, dan password sesuai kebutuhan jaringan.  
- Pastikan interface (`ether1-WAN`, `ether2-LAN`, `wlan1`) sesuai dengan perangkatmu.  
- Segera ubah password default `admin` agar router lebih aman.  
- Gunakan group `read`, `write`, dan `full` sesuai peran user.  

---

✍️ **Dokumentasi ini dapat dipush ke GitHub sebagai panduan konfigurasi dasar MikroTik.**
