#!/bin/bash
# Zabbix 7.0 LTS Interactive Installer (Ubuntu 22.04 / 24.04)

# Konfigurasi Warna
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 1. Cek Root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[ERROR] Harap jalankan script ini sebagai root (Gunakan sudo).${NC}"
  exit 1
fi

clear
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}      Zabbix 7.0 LTS Interactive Installer       ${NC}"
echo -e "${GREEN}=================================================${NC}"
echo ""

# 2. Sesi Interaktif (Input Pengguna)
echo -e -n "${YELLOW}Masukkan password untuk database Zabbix [default: ZabbixPass123!]: ${NC}"
read input_db_pass
DB_PASS=${input_db_pass:-ZabbixPass123!}

echo -e -n "${YELLOW}Masukkan Timezone Server (misal: Asia/Jakarta) [default: Asia/Jakarta]: ${NC}"
read input_tz
TIMEZONE=${input_tz:-Asia/Jakarta}

echo ""
echo -e "${GREEN}--- Ringkasan Konfigurasi ---${NC}"
echo "Password DB MariaDB : $DB_PASS"
echo "Timezone Server     : $TIMEZONE"
echo "OS Target           : Ubuntu $(lsb_release -rs)"
echo "-----------------------------"

echo -e -n "${YELLOW}Apakah data di atas sudah benar dan mulai instalasi? (y/n): ${NC}"
read confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${RED}[ABORT] Instalasi dibatalkan oleh pengguna.${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}[INFO] Memulai instalasi...${NC}"

# Set Timezone Server
timedatectl set-timezone "$TIMEZONE"

# 3. Menambahkan Repositori Zabbix
echo -e "${GREEN}[INFO] Mengunduh dan memasang repositori Zabbix 7.0...${NC}"
OS_VERSION=$(lsb_release -rs)
wget -q "https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-2+ubuntu${OS_VERSION}_all.deb" -O zabbix-release.deb
dpkg -i zabbix-release.deb > /dev/null 2>&1
apt-get update -y > /dev/null 2>&1

# 4. Instalasi Paket Zabbix & MariaDB
echo -e "${GREEN}[INFO] Menginstal Zabbix Server, Agent, Frontend, dan MariaDB (Mohon tunggu)...${NC}"
DEBIAN_FRONTEND=noninteractive apt-get install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent mariadb-server > /dev/null 2>&1

# 5. Konfigurasi Database MariaDB
echo -e "${GREEN}[INFO] Mengonfigurasi Database...${NC}"
systemctl start mariadb
systemctl enable mariadb > /dev/null 2>&1

mysql -uroot -e "CREATE DATABASE IF NOT EXISTS zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;"
mysql -uroot -e "CREATE USER IF NOT EXISTS 'zabbix'@'localhost' IDENTIFIED BY '${DB_PASS}';"
mysql -uroot -e "GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';"
mysql -uroot -e "SET GLOBAL log_bin_trust_function_creators = 1;"

# 6. Import Skema Database Zabbix
echo -e "${GREEN}[INFO] Mengimpor skema database Zabbix...${NC}"
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -p"${DB_PASS}" zabbix
mysql -uroot -e "SET GLOBAL log_bin_trust_function_creators = 0;"

# 7. Konfigurasi Zabbix Server Conf
echo -e "${GREEN}[INFO] Menerapkan konfigurasi password pada Zabbix Server...${NC}"
sed -i "s/# DBPassword=/DBPassword=${DB_PASS}/g" /etc/zabbix/zabbix_server.conf

# 8. Konfigurasi PHP Timezone untuk Apache
echo -e "${GREEN}[INFO] Mengonfigurasi Timezone PHP...${NC}"
sed -i "s|# php_value date.timezone Europe/Riga|php_value date.timezone ${TIMEZONE}|g" /etc/zabbix/apache.conf

# 9. Restart dan Cleanup
echo -e "${GREEN}[INFO] Memulai ulang layanan (Restarting Services)...${NC}"
systemctl restart zabbix-server zabbix-agent apache2
systemctl enable zabbix-server zabbix-agent apache2 > /dev/null 2>&1
rm -f zabbix-release.deb

echo ""
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}          INSTALASI ZABBIX 7.0 SELESAI!          ${NC}"
echo -e "${GREEN}=================================================${NC}"
echo -e "Akses Web Interface : ${YELLOW}http://$(hostname -I | awk '{print $1}')/zabbix${NC}"
echo ""
echo -e "${GREEN}Kredensial Login Default Web Zabbix:${NC}"
echo -e "Username : ${YELLOW}Admin${NC} (A besar)"
echo -e "Password : ${YELLOW}zabbix${NC}"
echo ""
echo -e "${GREEN}Kredensial Database (MariaDB):${NC}"
echo -e "DB User  : ${YELLOW}zabbix${NC}"
echo -e "DB Pass  : ${YELLOW}${DB_PASS}${NC}"
echo -e "${GREEN}=================================================${NC}"
