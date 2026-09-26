#!/bin/bash
# Zabbix 7.0 Clean Uninstaller (Menghapus Zabbix, MariaDB, Apache)

# Konfigurasi Warna
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Cek Root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[ERROR] Harap jalankan script ini sebagai root (Gunakan sudo).${NC}"
  exit 1
fi

clear
echo -e "${RED}=================================================${NC}"
echo -e "${RED}         ZABBIX COMPLETE UNINSTALLER             ${NC}"
echo -e "${GREEN}           Author : Zakaria                       "
echo -e "${RED}=================================================${NC}"
echo -e "${YELLOW}PERINGATAN: Script ini akan MENGHAPUS PERMANEN:${NC}"
echo " 1. Seluruh paket Zabbix (Server, Agent, Frontend)"
echo " 2. Web Server (Apache2)"
echo " 3. Database System (MariaDB) beserta SELURUH DATANYA"
echo " 4. Direktori konfigurasi dan log aplikasi tersebut"
echo ""

# Meminta konfirmasi menggunakan </dev/tty agar mendukung 'curl | bash'
read -p "Apakah Anda YAKIN ingin menghapus semuanya? (Ketik 'HAPUS' untuk lanjut): " confirm </dev/tty

if [ "$confirm" != "HAPUS" ]; then
    echo -e "${GREEN}[ABORT] Proses dibatalkan. Tidak ada yang dihapus.${NC}"
    exit 0
fi

echo -e "\n${YELLOW}[INFO] Menghentikan semua layanan (Services)...${NC}"
systemctl stop zabbix-server zabbix-agent apache2 mariadb >/dev/null 2>&1

echo -e "${YELLOW}[INFO] Menghapus paket Zabbix, Apache, dan MariaDB...${NC}"
DEBIAN_FRONTEND=noninteractive apt-get purge -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent zabbix-release >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get purge -y apache2 apache2-utils apache2-bin apache2-data >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get purge -y mariadb-server mariadb-client mariadb-common mysql-common >/dev/null 2>&1

echo -e "${YELLOW}[INFO] Menghapus paket yang sudah tidak digunakan (Autoremove)...${NC}"
DEBIAN_FRONTEND=noninteractive apt-get autoremove -y >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get autoclean -y >/dev/null 2>&1

echo -e "${YELLOW}[INFO] Menghapus direktori konfigurasi, log, dan database yang tersisa...${NC}"
# Hapus sisa file Zabbix
rm -rf /etc/zabbix
rm -rf /var/log/zabbix
rm -rf /usr/lib/zabbix
rm -rf /run/zabbix
rm -rf /etc/apt/sources.list.d/zabbix.list

# Hapus sisa file Apache
rm -rf /etc/apache2
rm -rf /var/log/apache2
rm -rf /var/www/html/zabbix

# Hapus sisa file Database MariaDB/MySQL
rm -rf /etc/mysql
rm -rf /var/lib/mysql
rm -rf /var/log/mysql

echo -e "${YELLOW}[INFO] Menghapus user dan group zabbix...${NC}"
userdel zabbix >/dev/null 2>&1
groupdel zabbix >/dev/null 2>&1

# Update repository setelah menghapus repo zabbix
apt-get update -y >/dev/null 2>&1

echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}   UNINSTALASI SELESAI. SERVER SUDAH BERSIH!     ${NC}"
echo -e "${GREEN}=================================================${NC}"
