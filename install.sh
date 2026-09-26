#!/bin/bash
# Zabbix 7.0 Main Installer (Entrypoint)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[ERROR] Harap jalankan dengan sudo.${NC}"
  exit 1
fi

clear
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}                ZABBIX 7.0                       ${NC}"
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}                Author : Zakaria                 ${NC}"
echo -e "${GREEN}=================================================${NC}"

# 1. Menu Interaktif
echo -e "${YELLOW}Pilih Database Server:${NC}"
echo "1) MariaDB / MySQL"
echo "2) PostgreSQL"
read -p "Pilihan (1/2) [1]: " db_choice </dev/tty
db_choice=${db_choice:-1}

echo -e "\n${YELLOW}Pilih Web Server:${NC}"
echo "1) Apache"
echo "2) NGINX"
read -p "Pilihan (1/2) [1]: " web_choice </dev/tty
web_choice=${web_choice:-1}

echo ""
read -p "Password DB Zabbix [ZabbixPass123!]: " input_db_pass </dev/tty
DB_PASS=${input_db_pass:-ZabbixPass123!}

read -p "Timezone (misal: Asia/Jakarta) [Asia/Jakarta]: " input_tz </dev/tty
TIMEZONE=${input_tz:-Asia/Jakarta}

# 2. Deteksi OS dan Eksekusi Script Module
source /etc/os-release
OS_ID=$ID

# GANTI URL INI DENGAN URL RAW GITHUB ANDA NANTI
REPO_URL="https://raw.githubusercontent.com/zaxrmdn/zabbix-installer/main/modules"

if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" ]]; then
    echo -e "\n${GREEN}[INFO] Mengalihkan ke modul instalasi Ubuntu/Debian...${NC}"
    # Mengunduh dan menjalankan modul ubuntu, serta mengirimkan variabel sebagai argumen ($1, $2, dst)
    curl -sSL "$REPO_URL/ubuntu_debian.sh" | bash -s -- "$db_choice" "$web_choice" "$DB_PASS" "$TIMEZONE" "$OS_ID" "$VERSION_ID"

elif [[ "$OS_ID" =~ ^(almalinux|rocky|centos|rhel)$ ]]; then
    echo -e "\n${GREEN}[INFO] Mengalihkan ke modul instalasi RHEL/CentOS...${NC}"
    curl -sSL "$REPO_URL/rhel_centos.sh" | bash -s -- "$db_choice" "$web_choice" "$DB_PASS" "$TIMEZONE" "$OS_ID" "$VERSION_ID"

else
    echo -e "${RED}[ERROR] OS tidak didukung.${NC}"
    exit 1
fi
