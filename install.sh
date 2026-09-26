#!/bin/bash
# Universal Zabbix 7.0 LTS Installer (Safe & Debug Mode)
# OS Support: Ubuntu, Debian, AlmaLinux, Rocky, CentOS
# Stack Support: MariaDB/PostgreSQL & Apache/NGINX

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[ERROR] Harap jalankan script ini sebagai root (Gunakan sudo).${NC}"
  exit 1
fi

clear
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}  UNIVERSAL ZABBIX 7.0 INTERACTIVE INSTALLER     ${NC}"
echo -e "${GREEN}=================================================${NC}"

# Deteksi OS
source /etc/os-release
OS_ID=$ID

if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" ]]; then
    OS_FAMILY="debian"
    OS_VER=$VERSION_ID
    PKG_INSTALL="DEBIAN_FRONTEND=noninteractive apt-get install -y"
    PKG_UPDATE="apt-get update -y"
elif [[ "$OS_ID" =~ ^(almalinux|rocky|centos|rhel)$ ]]; then
    OS_FAMILY="rhel"
    OS_VER=$(echo $VERSION_ID | cut -d'.' -f1)
    PKG_INSTALL="dnf install -y"
    PKG_UPDATE="dnf makecache"
else
    echo -e "${RED}[ERROR] OS ($PRETTY_NAME) tidak didukung oleh script ini.${NC}"
    exit 1
fi
echo -e "${CYAN}[INFO] Terdeteksi OS: $PRETTY_NAME (Keluarga $OS_FAMILY)${NC}\n"

echo -e "${YELLOW}Pilih Database Server:${NC}"
echo "1) MariaDB / MySQL"
echo "2) PostgreSQL"
read -p "Masukkan pilihan (1/2) [1]: " db_choice </dev/tty
db_choice=${db_choice:-1}

echo -e "\n${YELLOW}Pilih Web Server:${NC}"
echo "1) Apache"
echo "2) NGINX"
read -p "Masukkan pilihan (1/2) [1]: " web_choice </dev/tty
web_choice=${web_choice:-1}

echo ""
read -p "Masukkan password database Zabbix [ZabbixPass123!]: " input_db_pass </dev/tty
DB_PASS=${input_db_pass:-ZabbixPass123!}

read -p "Masukkan Timezone Server (misal: Asia/Jakarta) [Asia/Jakarta]: " input_tz </dev/tty
TIMEZONE=${input_tz:-Asia/Jakarta}

# Penentuan Paket
if [ "$OS_FAMILY" == "debian" ]; then
    DB_PKG=$([ "$db_choice" == "1" ] && echo "mariadb-server" || echo "postgresql")
    ZBX_DB_PKG=$([ "$db_choice" == "1" ] && echo "zabbix-server-mysql" || echo "zabbix-server-pgsql")
    
    if [ "$web_choice" == "1" ]; then
        WEB_PKG="apache2"
        ZBX_WEB_PKG="zabbix-apache-conf zabbix-frontend-php"
        SVC_WEB="apache2"
    else
        WEB_PKG="nginx php-fpm"
        ZBX_WEB_PKG="zabbix-nginx-conf zabbix-frontend-php"
        SVC_WEB="nginx"
    fi
    EXTRAS="zabbix-sql-scripts zabbix-agent"
    SVC_DB=$([ "$db_choice" == "1" ] && echo "mariadb" || echo "postgresql")
elif [ "$OS_FAMILY" == "rhel" ]; then
    DB_PKG=$([ "$db_choice" == "1" ] && echo "mariadb-server" || echo "postgresql-server")
    ZBX_DB_PKG=$([ "$db_choice" == "1" ] && echo "zabbix-server-mysql zabbix-web-mysql" || echo "zabbix-server-pgsql zabbix-web-pgsql")
    
    if [ "$web_choice" == "1" ]; then
        WEB_PKG="httpd php-fpm"
        ZBX_WEB_PKG="zabbix-apache-conf"
        SVC_WEB="httpd php-fpm"
    else
        WEB_PKG="nginx php-fpm"
        ZBX_WEB_PKG="zabbix-nginx-conf"
        SVC_WEB="nginx php-fpm"
    fi
    EXTRAS="zabbix-sql-scripts zabbix-selinux-policy zabbix-agent"
    SVC_DB=$([ "$db_choice" == "1" ] && echo "mariadb" || echo "postgresql")
fi

echo -e "\n${CYAN}[INFO] Menambahkan repositori Zabbix...${NC}"
if [ "$OS_FAMILY" == "debian" ]; then
    wget -q "https://repo.zabbix.com/zabbix/7.0/${OS_ID}/pool/main/z/zabbix-release/zabbix-release_latest_7.0+${OS_ID}${OS_VER}_all.deb" -O zabbix-release.deb
    dpkg -i zabbix-release.deb > /dev/null 2>&1
else
    rpm -Uvh "https://repo.zabbix.com/zabbix/7.0/rhel/${OS_VER}/x86_64/zabbix-release-7.0-2.el${OS_VER}.noarch.rpm" > /dev/null 2>&1 || true
    dnf clean all > /dev/null 2>&1
fi

echo -e "${CYAN}[INFO] Memperbarui repositori paket...${NC}"
$PKG_UPDATE

echo -e "${CYAN}[INFO] Menginstal Paket Zabbix, Database, dan Web Server...${NC}"
# Output instalasi sengaja dimunculkan agar jika error, penyebabnya terlihat
$PKG_INSTALL $ZBX_DB_PKG $ZBX_WEB_PKG $EXTRAS $DB_PKG $WEB_PKG

# Cek status instalasi
if [ $? -ne 0 ]; then
    echo -e "${RED}[ERROR] Instalasi paket GAGAL. Silakan cek pesan error di atas (kemungkinan apt terkunci atau repo tidak dapat diakses).${NC}"
    exit 1
fi

echo -e "\n${CYAN}[INFO] Mengonfigurasi Database Server...${NC}"
if [ "$db_choice" == "1" ]; then
    systemctl start mariadb
    systemctl enable mariadb > /dev/null 2>&1
    mysql -uroot -e "CREATE DATABASE IF NOT EXISTS zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;"
    mysql -uroot -e "CREATE USER IF NOT EXISTS 'zabbix'@'localhost' IDENTIFIED BY '${DB_PASS}';"
    mysql -uroot -e "GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';"
    mysql -uroot -e "SET GLOBAL log_bin_trust_function_creators = 1;"
    echo -e "${CYAN}[INFO] Mengimpor skema MariaDB...${NC}"
    zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -p"${DB_PASS}" zabbix
    mysql -uroot -e "SET GLOBAL log_bin_trust_function_creators = 0;"
else
    if [ "$OS_FAMILY" == "rhel" ]; then
        postgresql-setup --initdb > /dev/null 2>&1
        sed -i 's/ident/md5/g' /var/lib/pgsql/data/pg_hba.conf
        sed -i 's/peer/md5/g' /var/lib/pgsql/data/pg_hba.conf
    fi
    systemctl start postgresql
    systemctl enable postgresql > /dev/null 2>&1
    sudo -u postgres psql -c "CREATE ROLE zabbix WITH LOGIN PASSWORD '${DB_PASS}';" > /dev/null 2>&1
    sudo -u postgres createdb -O zabbix zabbix > /dev/null 2>&1
    echo -e "${CYAN}[INFO] Mengimpor skema PostgreSQL...${NC}"
    zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz | sudo -u zabbix psql zabbix > /dev/null 2>&1
fi

echo -e "${CYAN}[INFO] Mengonfigurasi Zabbix Server DB...${NC}"
sed -i "s/# DBPassword=/DBPassword=${DB_PASS}/g" /etc/zabbix/zabbix_server.conf

echo -e "${CYAN}[INFO] Mengonfigurasi Web Server Timezone dan Port...${NC}"
if [ "$OS_FAMILY" == "debian" ]; then
    if [ "$web_choice" == "1" ]; then
        sed -i "s|# php_value date.timezone Europe/Riga|php_value date.timezone ${TIMEZONE}|g" /etc/zabbix/apache.conf
    else
        sed -i "s|.*php_value\[date.timezone\].*|php_value[date.timezone] = ${TIMEZONE}|g" /etc/zabbix/php-fpm.conf
        PHP_VER=$(php -v | head -n 1 | awk '{print $2}' | cut -d '.' -f 1,2)
        SVC_WEB="nginx php${PHP_VER}-fpm"
    fi
elif [ "$OS_FAMILY" == "rhel" ]; then
    sed -i "s|; php_value\[date.timezone\] = Europe/Riga|php_value[date.timezone] = ${TIMEZONE}|g" /etc/php-fpm.d/zabbix.conf
fi

if [ "$web_choice" == "2" ]; then
    sed -i 's/#        listen          8080;/        listen          8080;/g' /etc/zabbix/nginx.conf
    sed -i 's/#        server_name     example.com;/        server_name     localhost;/g' /etc/zabbix/nginx.conf
fi

echo -e "${CYAN}[INFO] Memulai ulang semua layanan...${NC}"
systemctl restart zabbix-server zabbix-agent $SVC_WEB
systemctl enable zabbix-server zabbix-agent $SVC_WEB > /dev/null 2>&1
[ -f zabbix-release.deb ] && rm -f zabbix-release.deb

echo -e "\n${GREEN}=================================================${NC}"
echo -e "${GREEN}      INSTALASI ZABBIX 7.0 SELESAI!              ${NC}"
echo -e "${GREEN}=================================================${NC}"
if [ "$web_choice" == "2" ]; then
    echo -e "Akses Web : ${YELLOW}http://$(hostname -I | awk '{print $1}'):8080${NC} (via NGINX)"
else
    echo -e "Akses Web : ${YELLOW}http://$(hostname -I | awk '{print $1}')/zabbix${NC} (via Apache)"
fi
echo -e "Username  : ${YELLOW}Admin${NC} (A besar)"
echo -e "Password  : ${YELLOW}zabbix${NC}"
echo -e "================================================="
