#!/bin/bash
# Zabbix Module: Ubuntu & Debian

# Menerima lemparan variabel dari install.sh
DB_CHOICE=$1
WEB_CHOICE=$2
DB_PASS=$3
TIMEZONE=$4
OS_ID=$5
OS_VER=$6

# Set agar APT tidak interaktif
export DEBIAN_FRONTEND=noninteractive

# Penentuan Paket spesifik Ubuntu/Debian
DB_PKG=$([ "$DB_CHOICE" == "1" ] && echo "mariadb-server php-mysql" || echo "postgresql php-pgsql")
ZBX_DB_PKG=$([ "$DB_CHOICE" == "1" ] && echo "zabbix-server-mysql" || echo "zabbix-server-pgsql")

if [ "$WEB_CHOICE" == "1" ]; then
    WEB_PKG="apache2"
    ZBX_WEB_PKG="zabbix-apache-conf zabbix-frontend-php"
    SVC_WEB="apache2"
else
    WEB_PKG="nginx php-fpm"
    ZBX_WEB_PKG="zabbix-nginx-conf zabbix-frontend-php"
    SVC_WEB="nginx"
fi

echo "[INFO] Menambahkan Repositori Zabbix 7.0..."
wget -q "https://repo.zabbix.com/zabbix/7.0/${OS_ID}/pool/main/z/zabbix-release/zabbix-release_latest_7.0+${OS_ID}${OS_VER}_all.deb" -O zabbix-release.deb
dpkg -i zabbix-release.deb > /dev/null 2>&1
apt-get update -y

echo "[INFO] Menginstal Paket..."
apt-get install -y $ZBX_DB_PKG $ZBX_WEB_PKG zabbix-sql-scripts zabbix-agent $DB_PKG $WEB_PKG

# Konfigurasi Database
echo "[INFO] Konfigurasi Database..."
if [ "$DB_CHOICE" == "1" ]; then
    systemctl enable --now mariadb
    mysql -uroot -e "CREATE DATABASE IF NOT EXISTS zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;"
    mysql -uroot -e "CREATE USER IF NOT EXISTS 'zabbix'@'localhost' IDENTIFIED BY '${DB_PASS}';"
    mysql -uroot -e "GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';"
    mysql -uroot -e "SET GLOBAL log_bin_trust_function_creators = 1;"
    zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -p"${DB_PASS}" zabbix
    mysql -uroot -e "SET GLOBAL log_bin_trust_function_creators = 0;"
else
    systemctl enable --now postgresql
    sudo -u postgres psql -c "CREATE ROLE zabbix WITH LOGIN PASSWORD '${DB_PASS}';"
    sudo -u postgres createdb -O zabbix zabbix
    zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz | sudo -u zabbix psql zabbix
fi

# Konfigurasi Zabbix & Web Server
echo "[INFO] Konfigurasi Web dan Timezone..."
sed -i "s/# DBPassword=/DBPassword=${DB_PASS}/g" /etc/zabbix/zabbix_server.conf
timedatectl set-timezone "$TIMEZONE"

if [ "$WEB_CHOICE" == "1" ]; then
    sed -i "s|# php_value date.timezone Europe/Riga|php_value date.timezone ${TIMEZONE}|g" /etc/zabbix/apache.conf
else
    sed -i "s|.*php_value\[date.timezone\].*|php_value[date.timezone] = ${TIMEZONE}|g" /etc/zabbix/php-fpm.conf
    sed -i 's/#        listen          8080;/        listen          8080;/g' /etc/zabbix/nginx.conf
    sed -i 's/#        server_name     example.com;/        server_name     localhost;/g' /etc/zabbix/nginx.conf
    PHP_VER=$(php -v | head -n 1 | awk '{print $2}' | cut -d '.' -f 1,2)
    SVC_WEB="nginx php${PHP_VER}-fpm"
fi

# Fix hak akses agar tidak terjadi HTTP 500 saat setup frontend
chown -R www-data:www-data /etc/zabbix/web

echo "[INFO] Restart Layanan..."
systemctl restart zabbix-server zabbix-agent $SVC_WEB
systemctl enable zabbix-server zabbix-agent $SVC_WEB

echo "==========================================="
echo " Instalasi Ubuntu/Debian Selesai!"
echo "==========================================="
