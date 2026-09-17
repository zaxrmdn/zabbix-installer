#!/usr/bin/env bash

# ============================================================
# ZABBIX INTERACTIVE INSTALLER
# GitHub: zaxrmdn/zabbix-installer
#
# Supported:
#   Ubuntu 22.04 / 24.04 / 26.04
#   Debian 12 / 13
#   AlmaLinux 9
#   Rocky Linux 9
#
# Zabbix:
#   7.0
#   7.4
#   8.0
#
# Database:
#   MySQL / MariaDB
#   PostgreSQL
#
# Web:
#   Apache
#   Nginx
# ============================================================

set -Eeuo pipefail

SCRIPT_NAME="Zabbix Interactive Installer"

# ------------------------------------------------------------
# COLORS
# ------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ------------------------------------------------------------
# FUNCTIONS
# ------------------------------------------------------------

info() {
    echo -e "${CYAN}[INFO]${NC} $*"
}

ok() {
    echo -e "${GREEN}[OK]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

die() {
    error "$*"
    exit 1
}

pause() {
    read -rp "Press ENTER to continue..."
}

trap 'error "Installation failed at line $LINENO."' ERR

# ------------------------------------------------------------
# ROOT CHECK
# ------------------------------------------------------------

if [[ "${EUID}" -ne 0 ]]; then
    die "Run this script as root."
fi

if [[ ! -t 0 ]]; then
    die "Interactive terminal is required."
fi

# ------------------------------------------------------------
# OS DETECTION
# ------------------------------------------------------------

if [[ ! -f /etc/os-release ]]; then
    die "/etc/os-release not found."
fi

source /etc/os-release

OS_ID="${ID:-unknown}"
OS_VERSION="${VERSION_ID:-unknown}"
OS_NAME="${PRETTY_NAME:-$OS_ID $OS_VERSION}"

ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"

echo
echo "============================================================"
echo "              ZABBIX INTERACTIVE INSTALLER"
echo "============================================================"
echo
echo "Detected system:"
echo
echo "  OS       : $OS_NAME"
echo "  ID       : $OS_ID"
echo "  Version  : $OS_VERSION"
echo "  Arch     : $ARCH"
echo

# ------------------------------------------------------------
# VALIDATE SUPPORTED OS
# ------------------------------------------------------------

SUPPORTED_OS="false"

case "$OS_ID" in

    ubuntu)
        case "$OS_VERSION" in
            22.04|24.04|26.04)
                SUPPORTED_OS="true"
                ;;
        esac
        ;;

    debian)
        case "$OS_VERSION" in
            12|13)
                SUPPORTED_OS="true"
                ;;
        esac
        ;;

    almalinux|rocky)
        case "$OS_VERSION" in
            9*)
                SUPPORTED_OS="true"
                ;;
        esac
        ;;

esac

if [[ "$SUPPORTED_OS" != "true" ]]; then
    die "Unsupported OS: $OS_NAME"
fi

ok "Operating system is supported."

# ------------------------------------------------------------
# PACKAGE MANAGER
# ------------------------------------------------------------

if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" ]]; then
    PKG="apt"
else
    PKG="dnf"
fi

# ------------------------------------------------------------
# ZABBIX VERSION MENU
# ------------------------------------------------------------

echo
echo "Select Zabbix version:"
echo
echo "  1) Zabbix 7.0 LTS"
echo "  2) Zabbix 7.4"
echo "  3) Zabbix 8.0"
echo

while true; do
    read -rp "Choice [1]: " ZBX_CHOICE
    ZBX_CHOICE="${ZBX_CHOICE:-1}"

    case "$ZBX_CHOICE" in
        1)
            ZBX_VERSION="7.0"
            break
            ;;
        2)
            ZBX_VERSION="7.4"
            break
            ;;
        3)
            ZBX_VERSION="8.0"
            break
            ;;
        *)
            echo "Invalid choice."
            ;;
    esac
done

# ------------------------------------------------------------
# VALIDATE ZABBIX / OS COMBINATION
# ------------------------------------------------------------

case "$OS_ID" in

    ubuntu)
        case "$OS_VERSION" in
            22.04|24.04|26.04)
                ;;
            *)
                die "Unsupported Ubuntu version."
                ;;
        esac
        ;;

    debian)
        case "$OS_VERSION" in
            12|13)
                ;;
            *)
                die "Unsupported Debian version."
                ;;
        esac
        ;;

    almalinux|rocky)
        if [[ "$OS_VERSION" != 9* ]]; then
            die "Only version 9 is supported for $OS_ID."
        fi
        ;;

esac

# ------------------------------------------------------------
# DATABASE MENU
# ------------------------------------------------------------

echo
echo "Select database:"
echo
echo "  1) MySQL / MariaDB"
echo "  2) PostgreSQL"
echo

while true; do
    read -rp "Choice [1]: " DB_CHOICE
    DB_CHOICE="${DB_CHOICE:-1}"

    case "$DB_CHOICE" in
        1)
            DB_TYPE="mysql"
            break
            ;;
        2)
            DB_TYPE="pgsql"
            break
            ;;
        *)
            echo "Invalid choice."
            ;;
    esac
done

# ------------------------------------------------------------
# WEB SERVER MENU
# ------------------------------------------------------------

echo
echo "Select web server:"
echo
echo "  1) Apache"
echo "  2) Nginx"
echo

while true; do
    read -rp "Choice [1]: " WEB_CHOICE
    WEB_CHOICE="${WEB_CHOICE:-1}"

    case "$WEB_CHOICE" in
        1)
            WEB_SERVER="apache"
            break
            ;;
        2)
            WEB_SERVER="nginx"
            break
            ;;
        *)
            echo "Invalid choice."
            ;;
    esac
done

# ------------------------------------------------------------
# AGENT 2
# ------------------------------------------------------------

echo
read -rp "Install Zabbix Agent 2? [Y/n]: " INSTALL_AGENT
INSTALL_AGENT="${INSTALL_AGENT:-Y}"

case "$INSTALL_AGENT" in
    y|Y|yes|YES)
        INSTALL_AGENT="yes"
        ;;
    *)
        INSTALL_AGENT="no"
        ;;
esac

# ------------------------------------------------------------
# FIREWALL
# ------------------------------------------------------------

echo
read -rp "Configure firewall automatically? [y/N]: " CONFIG_FIREWALL
CONFIG_FIREWALL="${CONFIG_FIREWALL:-N}"

case "$CONFIG_FIREWALL" in
    y|Y|yes|YES)
        CONFIG_FIREWALL="yes"
        ;;
    *)
        CONFIG_FIREWALL="no"
        ;;
esac

# ------------------------------------------------------------
# DATABASE SETTINGS
# ------------------------------------------------------------

DB_NAME="zabbix"
DB_USER="zabbix"

echo
echo "Database configuration:"
echo
read -rp "Database name [$DB_NAME]: " INPUT
DB_NAME="${INPUT:-$DB_NAME}"

read -rp "Database user [$DB_USER]: " INPUT
DB_USER="${INPUT:-$DB_USER}"

while true; do
    read -rsp "Database password: " DB_PASSWORD
    echo

    if [[ -z "$DB_PASSWORD" ]]; then
        echo "Password cannot be empty."
        continue
    fi

    read -rsp "Confirm database password: " DB_PASSWORD_CONFIRM
    echo

    if [[ "$DB_PASSWORD" != "$DB_PASSWORD_CONFIRM" ]]; then
        echo "Passwords do not match."
        continue
    fi

    break
done

# ------------------------------------------------------------
# SUMMARY
# ------------------------------------------------------------

echo
echo "============================================================"
echo "                    INSTALLATION SUMMARY"
echo "============================================================"
echo
echo "OS             : $OS_NAME"
echo "Architecture   : $ARCH"
echo "Zabbix         : $ZBX_VERSION"
echo "Database       : $DB_TYPE"
echo "Web Server     : $WEB_SERVER"
echo "Agent 2        : $INSTALL_AGENT"
echo "Firewall       : $CONFIG_FIREWALL"
echo "Database Name  : $DB_NAME"
echo "Database User  : $DB_USER"
echo
echo "============================================================"
echo

read -rp "Start installation? [y/N]: " CONFIRM

case "$CONFIRM" in
    y|Y|yes|YES)
        ;;
    *)
        echo "Installation cancelled."
        exit 0
        ;;
esac

# ============================================================
# UBUNTU / DEBIAN
# ============================================================

install_debian_family() {

    info "Updating package index..."

    apt-get update

    info "Installing prerequisite packages..."

    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        wget \
        curl \
        ca-certificates \
        gnupg \
        lsb-release \
        apt-transport-https

    # --------------------------------------------------------
    # ZABBIX REPOSITORY
    # --------------------------------------------------------

    info "Installing Zabbix Official Repository..."

    local ZBX_REPO_URL=""
    local ZBX_REPO_FILE=""

    if [[ "$OS_ID" == "ubuntu" ]]; then

        ZBX_REPO_FILE="zabbix-release_latest_${ZBX_VERSION}+ubuntu${OS_VERSION}_all.deb"

        ZBX_REPO_URL="https://repo.zabbix.com/zabbix/${ZBX_VERSION}/release/ubuntu/pool/main/z/zabbix-release/${ZBX_REPO_FILE}"

    elif [[ "$OS_ID" == "debian" ]]; then

        ZBX_REPO_FILE="zabbix-release_latest_${ZBX_VERSION}+debian${OS_VERSION}_all.deb"

        ZBX_REPO_URL="https://repo.zabbix.com/zabbix/${ZBX_VERSION}/release/debian/pool/main/z/zabbix-release/${ZBX_REPO_FILE}"

    fi

    info "Repository:"
    echo "  $ZBX_REPO_URL"
    echo

    rm -f "/tmp/${ZBX_REPO_FILE}"

    if ! wget -q --show-progress "$ZBX_REPO_URL" \
        -O "/tmp/${ZBX_REPO_FILE}"; then

        die "Failed to download Zabbix repository package.

OS      : $OS_ID
Version : $OS_VERSION
Zabbix  : $ZBX_VERSION

Repository URL:
$ZBX_REPO_URL"
    fi

    dpkg -i "/tmp/${ZBX_REPO_FILE}"

    apt-get update

    # --------------------------------------------------------
    # VERIFY REPOSITORY
    # --------------------------------------------------------

    info "Checking Zabbix packages..."

    if ! apt-cache show zabbix-server-mysql >/dev/null 2>&1; then
        die "Zabbix repository is installed but zabbix-server-mysql is unavailable."
    fi

    if [[ "$INSTALL_AGENT" == "yes" ]]; then
        if ! apt-cache show zabbix-agent2 >/dev/null 2>&1; then
            die "zabbix-agent2 is unavailable from the configured repository."
        fi
    fi

    ok "Zabbix repository is working."

    # --------------------------------------------------------
    # INSTALL DATABASE
    # --------------------------------------------------------

    if [[ "$DB_TYPE" == "mysql" ]]; then

        info "Installing MySQL..."

        DEBIAN_FRONTEND=noninteractive apt-get install -y \
            mysql-server

    else

        info "Installing PostgreSQL..."

        DEBIAN_FRONTEND=noninteractive apt-get install -y \
            postgresql \
            postgresql-contrib

    fi

    # --------------------------------------------------------
    # INSTALL ZABBIX SERVER
    # --------------------------------------------------------

    if [[ "$DB_TYPE" == "mysql" ]]; then

        SERVER_PACKAGE="zabbix-server-mysql"
        SQL_PACKAGE="zabbix-sql-scripts"

    else

        SERVER_PACKAGE="zabbix-server-pgsql"
        SQL_PACKAGE="zabbix-sql-scripts"

    fi

    info "Installing Zabbix Server..."

    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        "$SERVER_PACKAGE" \
        "$SQL_PACKAGE"

    # --------------------------------------------------------
    # WEB SERVER
    # --------------------------------------------------------

    if [[ "$WEB_SERVER" == "apache" ]]; then

        info "Installing Apache frontend..."

        DEBIAN_FRONTEND=noninteractive apt-get install -y \
            apache2 \
            zabbix-frontend-php \
            zabbix-apache-conf \
            php-mysql \
            php-pgsql

    else

        info "Installing Nginx frontend..."

        DEBIAN_FRONTEND=noninteractive apt-get install -y \
            nginx \
            zabbix-frontend-php \
            php-fpm \
            php-mysql \
            php-pgsql

    fi

    # --------------------------------------------------------
    # AGENT
    # --------------------------------------------------------

    if [[ "$INSTALL_AGENT" == "yes" ]]; then

        info "Installing Zabbix Agent 2..."

        DEBIAN_FRONTEND=noninteractive apt-get install -y \
            zabbix-agent2

    fi
}

# ============================================================
# RHEL FAMILY
# ============================================================

install_rhel_family() {

    info "Installing prerequisite packages..."

    dnf install -y \
        wget \
        curl \
        ca-certificates

    # --------------------------------------------------------
    # REPOSITORY
    # --------------------------------------------------------

    local MAJOR_VERSION
    MAJOR_VERSION="${OS_VERSION%%.*}"

    local RHEL_ID

    case "$OS_ID" in
        almalinux)
            RHEL_ID="rhel"
            ;;
        rocky)
            RHEL_ID="rhel"
            ;;
        *)
            die "Unsupported RHEL derivative."
            ;;
    esac

    local ZBX_REPO_URL

    ZBX_REPO_URL="https://repo.zabbix.com/zabbix/${ZBX_VERSION}/release/rhel/${MAJOR_VERSION}/x86_64/zabbix-release-latest-${ZBX_VERSION}.el${MAJOR_VERSION}.noarch.rpm"

    info "Installing Zabbix Official Repository..."

    if ! rpm -Uvh "$ZBX_REPO_URL"; then
        die "Failed to install Zabbix repository:
$ZBX_REPO_URL"
    fi

    dnf clean all
    dnf makecache

    # --------------------------------------------------------
    # VERIFY
    # --------------------------------------------------------

    info "Checking Zabbix packages..."

    if ! dnf list available zabbix-server-mysql >/dev/null 2>&1; then
        die "Zabbix server package is unavailable."
    fi

    if [[ "$INSTALL_AGENT" == "yes" ]]; then

        if ! dnf list available zabbix-agent2 >/dev/null 2>&1; then
            die "zabbix-agent2 is unavailable."
        fi

    fi

    ok "Zabbix repository is working."

    # --------------------------------------------------------
    # DATABASE
    # --------------------------------------------------------

    if [[ "$DB_TYPE" == "mysql" ]]; then

        info "Installing MariaDB..."

        dnf install -y \
            mariadb-server \
            mariadb

        systemctl enable --now mariadb

    else

        info "Installing PostgreSQL..."

        dnf install -y \
            postgresql-server \
            postgresql

        if [[ ! -f /var/lib/pgsql/data/PG_VERSION ]]; then
            postgresql-setup --initdb
        fi

        systemctl enable --now postgresql

    fi

    # --------------------------------------------------------
    # ZABBIX SERVER
    # --------------------------------------------------------

    if [[ "$DB_TYPE" == "mysql" ]]; then

        dnf install -y \
            zabbix-server-mysql \
            zabbix-sql-scripts

    else

        dnf install -y \
            zabbix-server-pgsql \
            zabbix-sql-scripts

    fi

    # --------------------------------------------------------
    # WEB SERVER
    # --------------------------------------------------------

    if [[ "$WEB_SERVER" == "apache" ]]; then

        info "Installing Apache..."

        dnf install -y \
            httpd \
            zabbix-web-service \
            zabbix-web-mysql \
            zabbix-web-pgsql

    else

        info "Installing Nginx..."

        dnf install -y \
            nginx \
            zabbix-web-service \
            zabbix-web-mysql \
            zabbix-web-pgsql

    fi

    # --------------------------------------------------------
    # AGENT
    # --------------------------------------------------------

    if [[ "$INSTALL_AGENT" == "yes" ]]; then

        dnf install -y zabbix-agent2

    fi
}

# ============================================================
# INSTALL
# ============================================================

echo
echo "============================================================"
echo "                 STARTING INSTALLATION"
echo "============================================================"
echo

if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" ]]; then
    install_debian_family
else
    install_rhel_family
fi

# ============================================================
# DATABASE CONFIGURATION
# ============================================================

echo
info "Configuring database..."

if [[ "$DB_TYPE" == "mysql" ]]; then

    systemctl enable --now mysql 2>/dev/null || \
    systemctl enable --now mariadb

    MYSQL_CMD="mysql"

    "$MYSQL_CMD" <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`
CHARACTER SET utf8mb4
COLLATE utf8mb4_bin;

CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost'
IDENTIFIED BY '${DB_PASSWORD}';

ALTER USER '${DB_USER}'@'localhost'
IDENTIFIED BY '${DB_PASSWORD}';

GRANT ALL PRIVILEGES
ON \`${DB_NAME}\`.*
TO '${DB_USER}'@'localhost';

FLUSH PRIVILEGES;
SQL

    ok "MySQL/MariaDB database configured."

else

    systemctl enable --now postgresql

    runuser -u postgres -- psql <<SQL
DO \$\$
BEGIN
    IF NOT EXISTS (
        SELECT FROM pg_catalog.pg_roles
        WHERE rolname = '${DB_USER}'
    ) THEN
        CREATE ROLE ${DB_USER} LOGIN PASSWORD '${DB_PASSWORD}';
    ELSE
        ALTER ROLE ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';
    END IF;
END
\$\$;
SQL

    if ! runuser -u postgres -- psql -tAc \
        "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" \
        | grep -q 1; then

        runuser -u postgres -- createdb \
            -O "$DB_USER" \
            "$DB_NAME"
    fi

    ok "PostgreSQL database configured."

fi

# ============================================================
# IMPORT DATABASE SCHEMA
# ============================================================

echo
info "Importing Zabbix database schema..."

if [[ "$DB_TYPE" == "mysql" ]]; then

    ZBX_SQL="/usr/share/zabbix-sql-scripts/mysql/server.sql.gz"

    if [[ ! -f "$ZBX_SQL" ]]; then
        die "Zabbix MySQL schema not found:
$ZBX_SQL"
    fi

    zcat "$ZBX_SQL" | mysql \
        --default-character-set=utf8mb4 \
        -u"$DB_USER" \
        -p"$DB_PASSWORD" \
        "$DB_NAME"

else

    ZBX_SQL="/usr/share/zabbix-sql-scripts/postgresql/server.sql.gz"

    if [[ ! -f "$ZBX_SQL" ]]; then
        die "Zabbix PostgreSQL schema not found:
$ZBX_SQL"
    fi

    zcat "$ZBX_SQL" | \
        runuser -u postgres -- psql "$DB_NAME"

fi

ok "Database schema imported."

# ============================================================
# ZABBIX SERVER CONFIG
# ============================================================

info "Configuring Zabbix Server..."

ZBX_CONF="/etc/zabbix/zabbix_server.conf"

if [[ ! -f "$ZBX_CONF" ]]; then
    die "$ZBX_CONF not found."
fi

sed -i \
    "s|^#\?DBName=.*|DBName=${DB_NAME}|" \
    "$ZBX_CONF"

sed -i \
    "s|^#\?DBUser=.*|DBUser=${DB_USER}|" \
    "$ZBX_CONF"

if grep -q '^#DBPassword=' "$ZBX_CONF"; then

    sed -i \
        "s|^#DBPassword=.*|DBPassword=${DB_PASSWORD}|" \
        "$ZBX_CONF"

elif grep -q '^DBPassword=' "$ZBX_CONF"; then

    sed -i \
        "s|^DBPassword=.*|DBPassword=${DB_PASSWORD}|" \
        "$ZBX_CONF"

else

    echo "DBPassword=${DB_PASSWORD}" >> "$ZBX_CONF"

fi

# PostgreSQL does not need DBPassword in the same way,
# but leaving it is harmless only if authentication supports it.
if [[ "$DB_TYPE" == "pgsql" ]]; then
    sed -i '/^DBPassword=/d' "$ZBX_CONF"
fi

# ============================================================
# SERVICES
# ============================================================

echo
info "Enabling Zabbix Server..."

systemctl enable zabbix-server

systemctl restart zabbix-server

# ------------------------------------------------------------
# AGENT
# ------------------------------------------------------------

if [[ "$INSTALL_AGENT" == "yes" ]]; then

    info "Enabling Zabbix Agent 2..."

    systemctl enable zabbix-agent2
    systemctl restart zabbix-agent2

fi

# ------------------------------------------------------------
# WEB
# ------------------------------------------------------------

if [[ "$WEB_SERVER" == "apache" ]]; then

    systemctl enable apache2 2>/dev/null || \
    systemctl enable httpd

    systemctl restart apache2 2>/dev/null || \
    systemctl restart httpd

else

    systemctl enable nginx
    systemctl restart nginx

fi

# ============================================================
# FIREWALL
# ============================================================

if [[ "$CONFIG_FIREWALL" == "yes" ]]; then

    info "Configuring firewall..."

    if command -v ufw >/dev/null 2>&1; then

        ufw allow 22/tcp
        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw allow 10050/tcp
        ufw allow 10051/tcp

        ufw --force enable

    elif command -v firewall-cmd >/dev/null 2>&1; then

        systemctl enable --now firewalld

        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --permanent --add-port=10050/tcp
        firewall-cmd --permanent --add-port=10051/tcp

        firewall-cmd --reload

    fi

fi

# ============================================================
# VALIDATION
# ============================================================

echo
echo "============================================================"
echo "                     VALIDATION"
echo "============================================================"
echo

if systemctl is-active --quiet zabbix-server; then
    ok "Zabbix Server       : RUNNING"
else
    error "Zabbix Server       : NOT RUNNING"
fi

if [[ "$INSTALL_AGENT" == "yes" ]]; then

    if systemctl is-active --quiet zabbix-agent2; then
        ok "Zabbix Agent 2      : RUNNING"
    else
        error "Zabbix Agent 2      : NOT RUNNING"
    fi

fi

if [[ "$WEB_SERVER" == "apache" ]]; then

    if systemctl is-active --quiet apache2 2>/dev/null || \
       systemctl is-active --quiet httpd 2>/dev/null; then

        ok "Web Server          : RUNNING"

    else
        error "Web Server          : NOT RUNNING"
    fi

else

    if systemctl is-active --quiet nginx; then
        ok "Web Server          : RUNNING"
    else
        error "Web Server          : NOT RUNNING"
    fi

fi

# ============================================================
# SHOW PORTS
# ============================================================

echo
info "Listening ports:"

ss -lntp | grep -E ':(80|443|10050|10051)\b' || true

# ============================================================
# FINAL
# ============================================================

SERVER_IP="$(hostname -I | awk '{print $1}')"

echo
echo "============================================================"
echo "                 INSTALLATION COMPLETE"
echo "============================================================"
echo
echo "Zabbix Version : $ZBX_VERSION"
echo "Database       : $DB_TYPE"
echo "Web Server     : $WEB_SERVER"
echo
echo "Frontend:"
echo
echo "  http://${SERVER_IP}/zabbix"
echo
echo "Default Zabbix frontend login:"
echo
echo "  Username : Admin"
echo "  Password : zabbix"
echo
echo "Zabbix Server configuration:"
echo
echo "  $ZBX_CONF"
echo
echo "Useful commands:"
echo
echo "  systemctl status zabbix-server"
echo "  systemctl status zabbix-agent2"
echo "  journalctl -u zabbix-server -f"
echo
echo "============================================================"
