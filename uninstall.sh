#!/bin/bash
# Universal Zabbix 7.0 Clean Uninstaller
# OS Support: Ubuntu, Debian, AlmaLinux, Rocky, CentOS
# Menghapus Zabbix, MariaDB/PostgreSQL, dan Apache/NGINX

# Konfigurasi Warna
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Cek Hak Akses Root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[ERROR] Harap jalankan script ini sebagai root (Gunakan sudo).${NC}"
  exit 1
fi

clear
echo -e "${RED}=================================================${NC}"
echo -e "${RED}      UNIVERSAL ZABBIX COMPLETE UNINSTALLER      ${NC}"
echo -e "${RED}=================================================${NC}"
echo -e "${YELLOW}PERINGATAN: Script ini akan MENGHAPUS PERMANEN:${NC}"
echo " 1. Seluruh paket Zabbix (Server, Agent, Frontend, Repo)"
echo " 2. Web Server (Apache/httpd & NGINX) dan PHP-FPM"
echo " 3. Database Server (MariaDB & PostgreSQL) beserta SELURUH DATANYA"
echo " 4. Konfigurasi Firewall terkait Zabbix (Khusus RHEL)"
echo ""

read -p "Apakah Anda YAKIN ingin menghapus semuanya? (Ketik 'HAPUS' untuk lanjut): " confirm </dev/tty

if [ "$confirm" != "HAPUS" ]; then
    echo -e "${GREEN}[ABORT] Proses dibatalkan. Tidak ada yang dihapus.${NC}"
    exit 0
fi

# Deteksi OS
source /etc/os-release
OS_ID=$ID
if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" ]]; then
    OS_FAMILY="debian"
elif [[ "$OS_ID" =~ ^(almalinux|rocky|centos|rhel)$ ]]; then
    OS_FAMILY="rhel"
else
    echo -e "${RED}[ERROR] OS ($PRETTY_NAME) tidak dikenali.${NC}"
    exit 1
fi

echo -e "\n${YELLOW}[INFO] Menghentikan semua layanan (Services)...${NC}"
systemctl stop zabbix-server zabbix-agent apache2 httpd nginx php-fpm mariadb postgresql mysql >/dev/null 2>&1

echo -e "${YELLOW}[INFO] Menghapus paket-paket aplikasi ($OS_FAMILY)...${NC}"
if [ "$OS_FAMILY" == "debian" ]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get purge -y zabbix-server-mysql zabbix-server-pgsql zabbix-frontend-php zabbix-apache-conf zabbix-nginx-conf zabbix-sql-scripts zabbix-agent zabbix-release >/dev/null 2>&1
    apt-get purge -y apache2 apache2-utils apache2-bin apache2-data nginx nginx-common php-fpm >/dev/null 2>&1
    apt-get purge -y mariadb-server mariadb-client mysql-common postgresql postgresql-client >/dev/null 2>&1
    apt-get autoremove -y >/dev/null 2>&1
    apt-get autoclean -y >/dev/null 2>&1
elif [ "$OS_FAMILY" == "rhel" ]; then
    dnf remove -y zabbix-server-mysql zabbix-server-pgsql zabbix-web-mysql zabbix-web-pgsql zabbix-apache-conf zabbix-nginx-conf zabbix-sql-scripts zabbix-agent zabbix-release zabbix-selinux-policy >/dev/null 2>&1
    dnf remove -y httpd nginx php-fpm >/dev/null 2>&1
    dnf remove -y mariadb-server mariadb postgresql-server postgresql >/dev/null 2>&1
    dnf autoremove -y >/dev/null 2>&1
    dnf clean all >/dev/null 2>&1
fi

echo -e "${YELLOW}[INFO] Menghapus direktori konfigurasi, log, dan database yang tersisa...${NC}"
# Hapus file dan direktori Zabbix
rm -rf /etc/zabbix /var/log/zabbix /usr/lib/zabbix /run/zabbix /usr/share/zabbix
rm -f /etc/apt/sources.list.d/zabbix.list
rm -f /etc/yum.repos.d/zabbix*.repo

# Hapus file dan direktori Web Server
rm -rf /etc/apache2 /var/log/apache2
rm -rf /etc/httpd /var/log/httpd
rm -rf /etc/nginx /var/log/nginx
rm -rf /var/www/html/zabbix
rm -rf /etc/php* /var/log/php-fpm /etc/php-fpm.d

# Hapus file dan direktori Database
rm -rf /etc/mysql /var/lib/mysql /var/log/mysql /var/log/mariadb
rm -rf /var/lib/pgsql /var/log/postgresql /etc/postgresql

echo -e "${YELLOW}[INFO] Menghapus user dan group aplikasi...${NC}"
userdel zabbix >/dev/null 2>&1
groupdel zabbix >/dev/null 2>&1
userdel postgres >/dev/null 2>&1
userdel mysql >/dev/null 2>&1

if [ "$OS_FAMILY" == "rhel" ]; then
    echo -e "${YELLOW}[INFO] Membersihkan rule Firewall...${NC}"
    if command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --remove-service=http --permanent >/dev/null 2>&1
        firewall-cmd --remove-port=8080/tcp --permanent >/dev/null 2>&1
        firewall-cmd --remove-port=10050/tcp --permanent >/dev/null 2>&1
        firewall-cmd --remove-port=10051/tcp --permanent >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
    fi
fi

echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}   UNINSTALASI SELESAI. SERVER SUDAH BERSIH!     ${NC}"
echo -e "${GREEN}=================================================${NC}"
