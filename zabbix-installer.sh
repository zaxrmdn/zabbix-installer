```bash
#!/usr/bin/env bash

# ============================================================
# Zabbix Universal Interactive Installer
#
# Supported:
#   Ubuntu
#   Debian
#   AlmaLinux
#   Rocky Linux
#
# Components:
#   Zabbix Server
#   Zabbix Frontend
#   Zabbix Agent 2
#   MySQL / PostgreSQL
#   Apache / Nginx
#
# Usage:
#   sudo bash install-zabbix.sh
#
# GitHub:
#   curl -fsSL https://raw.githubusercontent.com/USERNAME/
#   zabbix-installer/main/install-zabbix.sh | sudo bash
# ============================================================

set -Eeuo pipefail

# ============================================================
# COLORS
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================
# VARIABLES
# ============================================================

DISTRO=""
DISTRO_VERSION=""
DISTRO_CODENAME=""

ZABBIX_VERSION=""
ZABBIX_MAJOR=""

DB_TYPE=""
WEB_TYPE=""

INSTALL_AGENT="yes"
CONFIGURE_FIREWALL="yes"

DB_NAME="zabbix"
DB_USER="zabbix"
DB_PASSWORD=""

SERVER_IP=""

# ============================================================
# FUNCTIONS
# ============================================================

msg() {
    echo -e "${CYAN}[*]${NC} $1"
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

pause() {
    echo ""
    read -r -p "Press ENTER to continue..."
}

# ============================================================
# HEADER
# ============================================================

show_header() {

    clear

    echo -e "${CYAN}"
    echo "============================================================"
    echo "              ZABBIX UNIVERSAL INSTALLER"
    echo "============================================================"
    echo -e "${NC}"

}

# ============================================================
# ROOT CHECK
# ============================================================

check_root() {

    if [[ "$EUID" -ne 0 ]]; then

        error "Script harus dijalankan sebagai root."

        echo ""
        echo "Gunakan:"
        echo "  sudo bash install-zabbix.sh"

        exit 1

    fi

}

# ============================================================
# OS DETECTION
# ============================================================

detect_os() {

    msg "Detecting operating system..."

    if [[ ! -f /etc/os-release ]]; then

        error "/etc/os-release tidak ditemukan."
        exit 1

    fi

    source /etc/os-release

    DISTRO="$ID"
    DISTRO_VERSION="$VERSION_ID"
    DISTRO_CODENAME="${VERSION_CODENAME:-}"

    case "$DISTRO" in

        ubuntu)
            success "Detected Ubuntu $DISTRO_VERSION"
            ;;

        debian)
            success "Detected Debian $DISTRO_VERSION"
            ;;

        almalinux)
            success "Detected AlmaLinux $DISTRO_VERSION"
            ;;

        rocky)
            success "Detected Rocky Linux $DISTRO_VERSION"
            ;;

        *)
            error "Distribution tidak didukung: $DISTRO"
            echo ""
            echo "Supported:"
            echo "  Ubuntu"
            echo "  Debian"
            echo "  AlmaLinux"
            echo "  Rocky Linux"
            exit 1
            ;;

    esac

}

# ============================================================
# DISTRO MENU
# ============================================================

select_distro() {

    show_header

    echo "Detected OS:"
    echo -e "  ${GREEN}$PRETTY_NAME${NC}"
    echo ""

    echo "Use detected distribution?"
    echo ""
    echo "  1) Yes"
    echo "  2) No - Select manually"
    echo ""

    read -r -p "Choice [1]: " CHOICE
    CHOICE="${CHOICE:-1}"

    if [[ "$CHOICE" == "1" ]]; then
        return
    fi

    echo ""
    echo "Select distribution:"
    echo ""
    echo "  1) Ubuntu"
    echo "  2) Debian"
    echo "  3) AlmaLinux"
    echo "  4) Rocky Linux"
    echo ""

    read -r -p "Choice: " DISTRO_CHOICE

    case "$DISTRO_CHOICE" in

        1)
            DISTRO="ubuntu"
            ;;

        2)
            DISTRO="debian"
            ;;

        3)
            DISTRO="almalinux"
            ;;

        4)
            DISTRO="rocky"
            ;;

        *)
            error "Invalid choice."
            exit 1
            ;;

    esac

    echo ""
    read -r -p "OS version [$DISTRO_VERSION]: " INPUT_VERSION

    if [[ -n "$INPUT_VERSION" ]]; then
        DISTRO_VERSION="$INPUT_VERSION"
    fi

}

# ============================================================
# ZABBIX VERSION
# ============================================================

select_zabbix_version() {

    show_header

    echo "Distribution:"
    echo "  $DISTRO $DISTRO_VERSION"
    echo ""

    echo "Select Zabbix version:"
    echo ""

    echo "  1) Zabbix 7.0 LTS"
    echo "  2) Zabbix 7.4"
    echo "  3) Zabbix 8.0"
    echo ""

    read -r -p "Choice: " ZBX_CHOICE

    case "$ZBX_CHOICE" in

        1)
            ZABBIX_VERSION="7.0"
            ZABBIX_MAJOR="7.0"
            ;;

        2)
            ZABBIX_VERSION="7.4"
            ZABBIX_MAJOR="7.4"
            ;;

        3)
            ZABBIX_VERSION="8.0"
            ZABBIX_MAJOR="8.0"
            ;;

        *)
            error "Invalid choice."
            exit 1
            ;;

    esac

}

# ============================================================
# DATABASE
# ============================================================

select_database() {

    show_header

    echo "Select database:"
    echo ""

    echo "  1) MySQL / MariaDB"
    echo "  2) PostgreSQL"
    echo ""

    read -r -p "Choice [1]: " DB_CHOICE
    DB_CHOICE="${DB_CHOICE:-1}"

    case "$DB_CHOICE" in

        1)
            DB_TYPE="mysql"
            ;;

        2)
            DB_TYPE="postgresql"
            ;;

        *)
            error "Invalid choice."
            exit 1
            ;;

    esac

}

# ============================================================
# WEB SERVER
# ============================================================

select_web() {

    show_header

    echo "Select web server:"
    echo ""

    echo "  1) Apache"
    echo "  2) Nginx"
    echo ""

    read -r -p "Choice [1]: " WEB_CHOICE
    WEB_CHOICE="${WEB_CHOICE:-1}"

    case "$WEB_CHOICE" in

        1)
            WEB_TYPE="apache"
            ;;

        2)
            WEB_TYPE="nginx"
            ;;

        *)
            error "Invalid choice."
            exit 1
            ;;

    esac

}

# ============================================================
# OPTIONAL COMPONENTS
# ============================================================

select_options() {

    show_header

    echo "Optional components"
    echo ""

    read -r -p "Install Zabbix Agent 2? [Y/n]: " INPUT

    INPUT="${INPUT:-Y}"

    if [[ "$INPUT" =~ ^[Nn]$ ]]; then
        INSTALL_AGENT="no"
    else
        INSTALL_AGENT="yes"
    fi

    echo ""

    read -r -p "Configure firewall? [Y/n]: " INPUT

    INPUT="${INPUT:-Y}"

    if [[ "$INPUT" =~ ^[Nn]$ ]]; then
        CONFIGURE_FIREWALL="no"
    else
        CONFIGURE_FIREWALL="yes"
    fi

}

# ============================================================
# DATABASE PASSWORD
# ============================================================

get_database_password() {

    show_header

    echo "Database configuration"
    echo ""

    read -r -p "Database name [zabbix]: " INPUT

    if [[ -n "$INPUT" ]]; then
        DB_NAME="$INPUT"
    fi

    read -r -p "Database user [zabbix]: " INPUT

    if [[ -n "$INPUT" ]]; then
        DB_USER="$INPUT"
    fi

    while true; do

        echo ""

        read -r -s -p "Database password: " DB_PASSWORD
        echo ""

        if [[ -z "$DB_PASSWORD" ]]; then
            error "Password tidak boleh kosong."
            continue
        fi

        read -r -s -p "Confirm password: " DB_PASSWORD_CONFIRM
        echo ""

        if [[ "$DB_PASSWORD" != "$DB_PASSWORD_CONFIRM" ]]; then

            error "Password tidak sama."
            continue

        fi

        break

    done

}

# ============================================================
# VALIDATE COMBINATION
# ============================================================

validate_selection() {

    show_header

    msg "Validating selected configuration..."

    # --------------------------------------------------------
    # Ubuntu
    # --------------------------------------------------------

    if [[ "$DISTRO" == "ubuntu" ]]; then

        case "$DISTRO_VERSION" in

            22.04|24.04)
                ;;

            *)
                error "Ubuntu $DISTRO_VERSION belum didukung."
                exit 1
                ;;

        esac

    fi

    # --------------------------------------------------------
    # Debian
    # --------------------------------------------------------

    if [[ "$DISTRO" == "debian" ]]; then

        case "$DISTRO_VERSION" in

            12|13)
                ;;

            *)
                error "Debian $DISTRO_VERSION belum didukung."
                exit 1
                ;;

        esac

    fi

    # --------------------------------------------------------
    # RHEL family
    # --------------------------------------------------------

    if [[ "$DISTRO" == "almalinux" ||
          "$DISTRO" == "rocky" ]]; then

        case "$DISTRO_VERSION" in

            9*)
                ;;

            *)
                error "RHEL-based version $DISTRO_VERSION belum didukung."
                exit 1
                ;;

        esac

    fi

    success "Configuration looks valid."

}

# ============================================================
# SHOW SUMMARY
# ============================================================

show_summary() {

    show_header

    SERVER_IP=$(hostname -I | awk '{print $1}')

    echo "Installation summary"
    echo ""
    echo "------------------------------------------------------------"
    echo "Operating System : $PRETTY_NAME"
    echo "Zabbix           : $ZABBIX_VERSION"
    echo "Database         : $DB_TYPE"
    echo "Web Server       : $WEB_TYPE"
    echo "Agent 2          : $INSTALL_AGENT"
    echo "Firewall         : $CONFIGURE_FIREWALL"
    echo "Database Name    : $DB_NAME"
    echo "Database User    : $DB_USER"
    echo "Server IP        : $SERVER_IP"
    echo "------------------------------------------------------------"
    echo ""

    read -r -p "Start installation? [y/N]: " CONFIRM

    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then

        echo ""
        warning "Installation cancelled."
        exit 0

    fi

}

# ============================================================
# INSTALL BASIC PACKAGES - DEBIAN
# ============================================================

install_debian_packages() {

    msg "Updating APT..."

    apt-get update

    apt-get install -y \
        wget \
        curl \
        gnupg \
        ca-certificates \
        lsb-release

}

# ============================================================
# INSTALL BASIC PACKAGES - RHEL
# ============================================================

install_rhel_packages() {

    msg "Updating DNF..."

    dnf -y update

    dnf install -y \
        wget \
        curl \
        ca-certificates \
        gnupg2

}

# ============================================================
# ZABBIX REPOSITORY
# ============================================================

install_zabbix_repository() {

    msg "Installing Zabbix $ZABBIX_VERSION repository..."

    case "$DISTRO" in

        ubuntu)

            if [[ "$DISTRO_VERSION" == "22.04" ]]; then

                REPO_URL="https://repo.zabbix.com/zabbix/$ZABBIX_VERSION/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest+ubuntu22.04_all.deb"

            elif [[ "$DISTRO_VERSION" == "24.04" ]]; then

                REPO_URL="https://repo.zabbix.com/zabbix/$ZABBIX_VERSION/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest+ubuntu24.04_all.deb"

            fi

            wget -q "$REPO_URL" -O /tmp/zabbix-release.deb

            dpkg -i /tmp/zabbix-release.deb

            apt-get update

            ;;

        debian)

            if [[ "$DISTRO_VERSION" == "12" ]]; then

                REPO_URL="https://repo.zabbix.com/zabbix/$ZABBIX_VERSION/release/debian/pool/main/z/zabbix-release/zabbix-release_latest+debian12_all.deb"

            elif [[ "$DISTRO_VERSION" == "13" ]]; then

                REPO_URL="https://repo.zabbix.com/zabbix/$ZABBIX_VERSION/release/debian/pool/main/z/zabbix-release/zabbix-release_latest+debian13_all.deb"

            fi

            wget -q "$REPO_URL" -O /tmp/zabbix-release.deb

            dpkg -i /tmp/zabbix-release.deb

            apt-get update

            ;;

        almalinux|rocky)

            if [[ "$DISTRO_VERSION" == 9* ]]; then

                REPO_URL="https://repo.zabbix.com/zabbix/$ZABBIX_VERSION/release/rhel/9/noarch/zabbix-release-latest.el9.noarch.rpm"

            fi

            rpm -Uvh "$REPO_URL"

            dnf clean all
            dnf makecache

            ;;

    esac

    success "Zabbix repository installed."

}

# ============================================================
# DATABASE - MYSQL
# ============================================================

install_mysql() {

    msg "Installing MySQL / MariaDB..."

    case "$DISTRO" in

        ubuntu|debian)

            apt-get install -y mysql-server

            systemctl enable --now mysql

            ;;

        almalinux|rocky)

            dnf install -y mariadb-server

            systemctl enable --now mariadb

            ;;

    esac

}

# ============================================================
# DATABASE - POSTGRESQL
# ============================================================

install_postgresql() {

    msg "Installing PostgreSQL..."

    case "$DISTRO" in

        ubuntu|debian)

            apt-get install -y postgresql

            systemctl enable --now postgresql

            ;;

        almalinux|rocky)

            dnf install -y postgresql-server postgresql-contrib

            if [[ ! -f /var/lib/pgsql/data/PG_VERSION ]]; then
                postgresql-setup --initdb
            fi

            systemctl enable --now postgresql

            ;;

    esac

}

# ============================================================
# WEB SERVER
# ============================================================

install_web_server() {

    msg "Installing $WEB_TYPE..."

    case "$WEB_TYPE" in

        apache)

            case "$DISTRO" in

                ubuntu|debian)

                    apt-get install -y apache2

                    systemctl enable --now apache2

                    ;;

                almalinux|rocky)

                    dnf install -y httpd

                    systemctl enable --now httpd

                    ;;

            esac

            ;;

        nginx)

            case "$DISTRO" in

                ubuntu|debian)

                    apt-get install -y nginx

                    systemctl enable --now nginx

                    ;;

                almalinux|rocky)

                    dnf install -y nginx

                    systemctl enable --now nginx

                    ;;

            esac

            ;;

    esac

}

# ============================================================
# ZABBIX SERVER
# ============================================================

install_zabbix_server() {

    msg "Installing Zabbix Server packages..."

    case "$DB_TYPE" in

        mysql)

            case "$WEB_TYPE" in

                apache)

                    if [[ "$DISTRO" == "ubuntu" ||
                          "$DISTRO" == "debian" ]]; then

                        apt-get install -y \
                            zabbix-server-mysql \
                            zabbix-frontend-php \
                            zabbix-apache-conf \
                            zabbix-sql-scripts

                    else

                        dnf install -y \
                            zabbix-server-mysql \
                            zabbix-web-mysql \
                            zabbix-apache-conf \
                            zabbix-sql-scripts

                    fi

                    ;;

                nginx)

                    if [[ "$DISTRO" == "ubuntu" ||
                          "$DISTRO" == "debian" ]]; then

                        apt-get install -y \
                            zabbix-server-mysql \
                            zabbix-frontend-php \
                            zabbix-nginx-conf \
                            zabbix-sql-scripts

                    else

                        dnf install -y \
                            zabbix-server-mysql \
                            zabbix-web-mysql \
                            zabbix-nginx-conf \
                            zabbix-sql-scripts

                    fi

                    ;;

            esac

            ;;

        postgresql)

            case "$WEB_TYPE" in

                apache)

                    if [[ "$DISTRO" == "ubuntu" ||
                          "$DISTRO" == "debian" ]]; then

                        apt-get install -y \
                            zabbix-server-pgsql \
                            zabbix-frontend-php \
                            zabbix-apache-conf \
                            zabbix-sql-scripts

                    else

                        dnf install -y \
                            zabbix-server-pgsql \
                            zabbix-web-pgsql \
                            zabbix-apache-conf \
                            zabbix-sql-scripts

                    fi

                    ;;

                nginx)

                    if [[ "$DISTRO" == "ubuntu" ||
                          "$DISTRO" == "debian" ]]; then

                        apt-get install -y \
                            zabbix-server-pgsql \
                            zabbix-frontend-php \
                            zabbix-nginx-conf \
                            zabbix-sql-scripts

                    else

                        dnf install -y \
                            zabbix-server-pgsql \
                            zabbix-web-pgsql \
                            zabbix-nginx-conf \
                            zabbix-sql-scripts

                    fi

                    ;;

            esac

            ;;

    esac

}

# ============================================================
# AGENT 2
# ============================================================

install_agent() {

    if [[ "$INSTALL_AGENT" != "yes" ]]; then
        return
    fi

    msg "Installing Zabbix Agent 2..."

    case "$DISTRO" in

        ubuntu|debian)

            apt-get install -y \
                zabbix-agent2 \
                zabbix-agent2-plugin-*

            ;;

        almalinux|rocky)

            dnf install -y \
                zabbix-agent2 \
                zabbix-agent2-plugin-*

            ;;

    esac

    systemctl enable zabbix-agent2

}

# ============================================================
# MYSQL DATABASE CONFIGURATION
# ============================================================

configure_mysql() {

    msg "Creating Zabbix MySQL database..."

    mysql <<MYSQL

CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`
CHARACTER SET utf8mb4
COLLATE utf8mb4_bin;

CREATE USER IF NOT EXISTS '$DB_USER'@'localhost'
IDENTIFIED BY '$DB_PASSWORD';

ALTER USER '$DB_USER'@'localhost'
IDENTIFIED BY '$DB_PASSWORD';

GRANT ALL PRIVILEGES ON \`$DB_NAME\`.*
TO '$DB_USER'@'localhost';

FLUSH PRIVILEGES;

MYSQL

    success "MySQL database created."

}

# ============================================================
# POSTGRESQL DATABASE CONFIGURATION
# ============================================================

configure_postgresql() {

    msg "Creating PostgreSQL database..."

    sudo -u postgres psql <<SQL

CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';

CREATE DATABASE $DB_NAME OWNER $DB_USER;

SQL

    success "PostgreSQL database created."

}

# ============================================================
# IMPORT DATABASE
# ============================================================

import_database() {

    msg "Importing Zabbix database schema..."

    case "$DB_TYPE" in

        mysql)

            if [[ -f /usr/share/zabbix-sql-scripts/mysql/server.sql.gz ]]; then

                zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | \
                    mysql \
                    --default-character-set=utf8mb4 \
                    -u"$DB_USER" \
                    -p"$DB_PASSWORD" \
                    "$DB_NAME"

            else

                error "MySQL schema tidak ditemukan."
                exit 1

            fi

            ;;

        postgresql)

            if [[ -f /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz ]]; then

                zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz | \
                    sudo -u postgres psql "$DB_NAME"

            else

                error "PostgreSQL schema tidak ditemukan."
                exit 1

            fi

            ;;

    esac

    success "Database schema imported."

}

# ============================================================
# CONFIGURE ZABBIX SERVER
# ============================================================

configure_zabbix_server() {

    msg "Configuring Zabbix Server..."

    ZBX_CONFIG="/etc/zabbix/zabbix_server.conf"

    if [[ ! -f "$ZBX_CONFIG" ]]; then

        error "$ZBX_CONFIG tidak ditemukan."
        exit 1

    fi

    cp "$ZBX_CONFIG" \
       "$ZBX_CONFIG.backup.$(date +%Y%m%d-%H%M%S)"

    sed -i '/^DBName=/d' "$ZBX_CONFIG"
    sed -i '/^DBUser=/d' "$ZBX_CONFIG"
    sed -i '/^DBPassword=/d' "$ZBX_CONFIG"

    cat >> "$ZBX_CONFIG" <<EOF

DBName=$DB_NAME
DBUser=$DB_USER
DBPassword=$DB_PASSWORD

EOF

    success "Zabbix Server configured."

}

# ============================================================
# FIREWALL
# ============================================================

configure_firewall() {

    if [[ "$CONFIGURE_FIREWALL" != "yes" ]]; then
        return
    fi

    msg "Configuring firewall..."

    case "$DISTRO" in

        ubuntu|debian)

            apt-get install -y ufw

            ufw allow OpenSSH
            ufw allow 80/tcp
            ufw allow 443/tcp
            ufw allow 10050/tcp
            ufw allow 10051/tcp

            ufw --force enable

            ;;

        almalinux|rocky)

            dnf install -y firewalld

            systemctl enable --now firewalld

            firewall-cmd --permanent --add-service=http
            firewall-cmd --permanent --add-service=https
            firewall-cmd --permanent --add-port=10050/tcp
            firewall-cmd --permanent --add-port=10051/tcp

            firewall-cmd --reload

            ;;

    esac

    success "Firewall configured."

}

# ============================================================
# START SERVICES
# ============================================================

start_services() {

    msg "Starting Zabbix services..."

    systemctl enable zabbix-server
    systemctl restart zabbix-server

    if [[ "$INSTALL_AGENT" == "yes" ]]; then

        systemctl restart zabbix-agent2

    fi

    case "$WEB_TYPE" in

        apache)

            if systemctl list-unit-files | grep -q "^apache2"; then
                systemctl restart apache2
            fi

            if systemctl list-unit-files | grep -q "^httpd"; then
                systemctl restart httpd
            fi

            ;;

        nginx)

            systemctl restart nginx

            ;;

    esac

    success "Services started."

}

# ============================================================
# VALIDATE
# ============================================================

validate_installation() {

    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo "Installation validation"
    echo -e "${CYAN}============================================================${NC}"
    echo ""

    # Zabbix server

    if systemctl is-active --quiet zabbix-server; then
        success "Zabbix Server : RUNNING"
    else
        error "Zabbix Server : FAILED"
    fi

    # Agent

    if [[ "$INSTALL_AGENT" == "yes" ]]; then

        if systemctl is-active --quiet zabbix-agent2; then
            success "Zabbix Agent 2 : RUNNING"
        else
            error "Zabbix Agent 2 : FAILED"
        fi

    fi

    # Web

    if [[ "$WEB_TYPE" == "nginx" ]]; then

        if systemctl is-active --quiet nginx; then
            success "Nginx : RUNNING"
        else
            error "Nginx : FAILED"
        fi

    fi

    if [[ "$WEB_TYPE" == "apache" ]]; then

        if systemctl is-active --quiet apache2 2>/dev/null ||
           systemctl is-active --quiet httpd 2>/dev/null; then

            success "Apache : RUNNING"

        else

            error "Apache : FAILED"

        fi

    fi

}

# ============================================================
# FINAL INFORMATION
# ============================================================

show_result() {

    SERVER_IP=$(hostname -I | awk '{print $1}')

    echo ""
    echo -e "${GREEN}"
    echo "============================================================"
    echo "              INSTALLATION COMPLETED"
    echo "============================================================"
    echo -e "${NC}"

    echo "Zabbix Version : $ZABBIX_VERSION"
    echo "OS             : $PRETTY_NAME"
    echo "Database       : $DB_TYPE"
    echo "Web Server     : $WEB_TYPE"
    echo ""
    echo "Server IP      : $SERVER_IP"
    echo "Zabbix Web     : http://$SERVER_IP/zabbix"
    echo ""
    echo "Zabbix Server  : 10051/TCP"
    echo "Agent 2        : 10050/TCP"
    echo ""
    echo "Default frontend:"
    echo "  Username : Admin"
    echo "  Password : zabbix"
    echo ""
    echo -e "${YELLOW}IMPORTANT: Segera ubah password Admin.${NC}"
    echo ""
    echo "Troubleshooting:"
    echo ""
    echo "  systemctl status zabbix-server"
    echo "  journalctl -u zabbix-server -f"
    echo "  tail -f /var/log/zabbix/zabbix_server.log"
    echo ""

}

# ============================================================
# MAIN INSTALLATION
# ============================================================

main() {

    check_root

    detect_os

    select_distro

    select_zabbix_version

    select_database

    select_web

    select_options

    get_database_password

    validate_selection

    show_summary

    show_header

    echo "Starting installation..."
    echo ""

    case "$DISTRO" in

        ubuntu|debian)
            install_debian_packages
            ;;

        almalinux|rocky)
            install_rhel_packages
            ;;

    esac

    install_zabbix_repository

    case "$DB_TYPE" in

        mysql)
            install_mysql
            ;;

        postgresql)
            install_postgresql
            ;;

    esac

    install_web_server

    install_zabbix_server

    install_agent

    case "$DB_TYPE" in

        mysql)
            configure_mysql
            ;;

        postgresql)
            configure_postgresql
            ;;

    esac

    import_database

    configure_zabbix_server

    configure_firewall

    start_services

    validate_installation

    show_result

}

# ============================================================
# RUN
# ============================================================

main "$@"
