#!/bin/bash
#
# 09 - Database Hardening
# Secure MySQL, PostgreSQL, and other databases
# Usage: curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/09_database_hardening.sh | sudo bash
#

set -euo pipefail

echo "========================================="
echo "  DATABASE HARDENING"
echo "========================================="

if [[ $(id -u) -ne 0 ]]; then
    echo "[!] Run this script as root."
    exit 1
fi

echo "[1] Detecting installed databases"

# Check for MySQL/MariaDB
if command -v mysql &>/dev/null; then
    echo "    -> MySQL/MariaDB detected"
    MYSQL_INSTALLED=true
else
    echo "    -> MySQL/MariaDB not found"
    MYSQL_INSTALLED=false
fi

# Check for PostgreSQL
if command -v psql &>/dev/null; then
    echo "    -> PostgreSQL detected"
    POSTGRES_INSTALLED=true
else
    echo "    -> PostgreSQL not found"
    POSTGRES_INSTALLED=false
fi

# Check for MongoDB
if command -v mongod &>/dev/null; then
    echo "    -> MongoDB detected"
    MONGO_INSTALLED=true
else
    echo "    -> MongoDB not found"
    MONGO_INSTALLED=false
fi

echo ""
echo "[2] MySQL/MariaDB hardening"

if [[ "$MYSQL_INSTALLED" == "true" ]]; then
    echo "    Securing MySQL/MariaDB..."
    
    # Get current root password
    read -sp "Enter current MySQL root password (press enter if none): " CURRENT_ROOT_PW
    echo ""
    read -sp "Enter NEW MySQL root password: " NEW_ROOT_PW
    echo ""
    
    # Test connection
    if mysql -u root -p"$CURRENT_ROOT_PW" -e "SELECT 1;" &>/dev/null; then
        echo "    -> Connection successful, applying security measures..."
        
        # Change root password
        mysql -u root -p"$CURRENT_ROOT_PW" -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$NEW_ROOT_PW';" 2>/dev/null || \
        mysql -u root -p"$CURRENT_ROOT_PW" -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$NEW_ROOT_PW');"
        echo "      -> Root password changed"
        
        # Remove anonymous users
        mysql -u root -p"$NEW_ROOT_PW" -e "DELETE FROM mysql.user WHERE User='';"
        echo "      -> Anonymous users removed"
        
        # Disallow root remote login
        mysql -u root -p"$NEW_ROOT_PW" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
        echo "      -> Remote root login disabled"
        
        # Remove test database
        mysql -u root -p"$NEW_ROOT_PW" -e "DROP DATABASE IF EXISTS test;"
        mysql -u root -p"$NEW_ROOT_PW" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
        echo "      -> Test database removed"
        
        # Create backup user (limited privileges)
        mysql -u root -p"$NEW_ROOT_PW" -e "CREATE USER IF NOT EXISTS 'backup'@'localhost' IDENTIFIED BY '$(openssl rand -base64 12)';"
        mysql -u root -p"$NEW_ROOT_PW" -e "GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER ON *.* TO 'backup'@'localhost';"
        echo "      -> Backup user created"
        
        # Check for weak passwords
        echo "      -> Checking for weak user passwords..."
        mysql -u root -p"$NEW_ROOT_PW" -e "SELECT User, Host FROM mysql.user WHERE authentication_string = '' OR authentication_string IS NULL;" | while read user host; do
            if [[ "$user" != "User" ]]; then
                echo "        [!] User with empty password: $user@$host"
            fi
        done
        
        # Flush privileges
        mysql -u root -p"$NEW_ROOT_PW" -e "FLUSH PRIVILEGES;"
        echo "      -> Privileges flushed"
        
    else
        echo "    -> Could not connect to MySQL with provided credentials"
        echo "    -> Manual MySQL hardening required"
    fi
    
    # Secure MySQL configuration
    echo "    -> Checking MySQL configuration..."
    
    MYSQL_CONFIG="/etc/mysql/my.cnf"
    [[ ! -f "$MYSQL_CONFIG" ]] && MYSQL_CONFIG="/etc/my.cnf"
    [[ ! -f "$MYSQL_CONFIG" ]] && MYSQL_CONFIG="/etc/mysql/mysql.conf.d/mysqld.cnf"
    
    if [[ -f "$MYSQL_CONFIG" ]]; then
        # Backup config
        cp "$MYSQL_CONFIG" "${MYSQL_CONFIG}.backup"
        
        # Security settings
        if ! grep -q "bind-address" "$MYSQL_CONFIG"; then
            echo "" >> "$MYSQL_CONFIG"
            echo "# Security settings" >> "$MYSQL_CONFIG"
            echo "bind-address = 127.0.0.1" >> "$MYSQL_CONFIG"
            echo "      -> Bound to localhost only"
        fi
        
        if ! grep -q "local-infile" "$MYSQL_CONFIG"; then
            echo "local-infile = 0" >> "$MYSQL_CONFIG"
            echo "      -> Local file loading disabled"
        fi
        
        # Restart MySQL to apply config changes
        systemctl restart mysql 2>/dev/null || systemctl restart mariadb 2>/dev/null
    fi
    
    unset CURRENT_ROOT_PW NEW_ROOT_PW
fi

echo ""
echo "[3] PostgreSQL hardening"

if [[ "$POSTGRES_INSTALLED" == "true" ]]; then
    echo "    Securing PostgreSQL..."
    
    # Get PostgreSQL version and data directory
    PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -o '[0-9]\+\.[0-9]\+' | head -1)
    PG_DATA_DIR="/var/lib/postgresql/$PG_VERSION/main"
    [[ ! -d "$PG_DATA_DIR" ]] && PG_DATA_DIR=$(sudo -u postgres psql -t -c "SHOW data_directory;" | tr -d ' ')
    
    echo "    -> PostgreSQL version: $PG_VERSION"
    echo "    -> Data directory: $PG_DATA_DIR"
    
    # Change postgres user password
    read -sp "Enter NEW password for postgres user: " POSTGRES_PW
    echo ""
    sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$POSTGRES_PW';"
    echo "      -> postgres user password changed"
    
    # Configure authentication
    PG_HBA_CONF="$PG_DATA_DIR/pg_hba.conf"
    if [[ -f "$PG_HBA_CONF" ]]; then
        cp "$PG_HBA_CONF" "$PG_HBA_CONF.backup"
        
        # Require passwords for local connections
        sed -i 's/local.*all.*all.*peer/local   all             all                                     md5/' "$PG_HBA_CONF"
        sed -i 's/local.*all.*all.*trust/local   all             all                                     md5/' "$PG_HBA_CONF"
        echo "      -> Local authentication requires passwords"
    fi
    
    # Configure postgresql.conf for security
    PG_CONF="$PG_DATA_DIR/postgresql.conf"
    if [[ -f "$PG_CONF" ]]; then
        cp "$PG_CONF" "$PG_CONF.backup"
        
        # Listen only on localhost
        sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" "$PG_CONF"
        echo "      -> Listening on localhost only"
        
        # Enable logging
        sed -i "s/#log_connections = off/log_connections = on/" "$PG_CONF"
        sed -i "s/#log_disconnections = off/log_disconnections = on/" "$PG_CONF"
        sed -i "s/#log_statement = 'none'/log_statement = 'all'/" "$PG_CONF"
        echo "      -> Enhanced logging enabled"
    fi
    
    # Restart PostgreSQL
    systemctl restart postgresql
    echo "      -> PostgreSQL restarted"
    
    unset POSTGRES_PW
fi

echo ""
echo "[4] MongoDB hardening"

if [[ "$MONGO_INSTALLED" == "true" ]]; then
    echo "    Securing MongoDB..."
    
    # Enable authentication
    MONGO_CONF="/etc/mongod.conf"
    if [[ -f "$MONGO_CONF" ]]; then
        cp "$MONGO_CONF" "$MONGO_CONF.backup"
        
        # Enable security
        if ! grep -q "security:" "$MONGO_CONF"; then
            echo "" >> "$MONGO_CONF"
            echo "security:" >> "$MONGO_CONF"
            echo "  authorization: enabled" >> "$MONGO_CONF"
            echo "      -> Authentication enabled"
        fi
        
        # Bind to localhost
        sed -i 's/bindIp: 0.0.0.0/bindIp: 127.0.0.1/' "$MONGO_CONF"
        echo "      -> Bound to localhost only"
        
        systemctl restart mongod
    fi
    
    # Create admin user
    read -sp "Enter password for MongoDB admin user: " MONGO_ADMIN_PW
    echo ""
    
    mongo admin --eval "db.createUser({user: 'admin', pwd: '$MONGO_ADMIN_PW', roles: [{role: 'userAdminAnyDatabase', db: 'admin'}, {role: 'readWriteAnyDatabase', db: 'admin'}]})" 2>/dev/null || echo "      -> Admin user may already exist"
    
    unset MONGO_ADMIN_PW
fi

echo ""
echo "[5] Database security audit"

echo "    -> Checking database processes and ports..."
ss -tulpn | grep -E ":3306|:5432|:27017" | while read line; do
    port=$(echo "$line" | awk '{print $5}' | sed 's/.*://')
    case $port in
        3306) echo "      MySQL/MariaDB listening: $line" ;;
        5432) echo "      PostgreSQL listening: $line" ;;
        27017) echo "      MongoDB listening: $line" ;;
    esac
done

echo "    -> Checking for database files with weak permissions..."
find /var/lib/mysql /var/lib/postgresql /var/lib/mongodb -type f -perm /o+rwx 2>/dev/null | head -5 | while read file; do
    echo "      [!] World-accessible: $file"
done

echo "    -> Checking for database backup files..."
find /tmp /var/tmp /home -name "*.sql" -o -name "*.dump" -o -name "*.bak" 2>/dev/null | head -5 | while read backup; do
    echo "      Database backup found: $backup"
    ls -la "$backup"
done

echo ""
echo "[6] Database firewall configuration"

if command -v ufw &>/dev/null; then
    echo "    -> Configuring UFW for databases..."
    
    # MySQL/MariaDB - only allow localhost by default
    if [[ "$MYSQL_INSTALLED" == "true" ]]; then
        ufw deny 3306/tcp comment 'MySQL - denied by default'
        echo "      -> MySQL external access denied"
    fi
    
    # PostgreSQL - only allow localhost by default
    if [[ "$POSTGRES_INSTALLED" == "true" ]]; then
        ufw deny 5432/tcp comment 'PostgreSQL - denied by default'
        echo "      -> PostgreSQL external access denied"
    fi
    
    # MongoDB - only allow localhost by default
    if [[ "$MONGO_INSTALLED" == "true" ]]; then
        ufw deny 27017/tcp comment 'MongoDB - denied by default'
        echo "      -> MongoDB external access denied"
    fi
    
elif command -v firewall-cmd &>/dev/null; then
    echo "    -> Configuring firewalld for databases..."
    
    # Remove database services from public zone
    for service in mysql postgresql mongodb; do
        firewall-cmd --zone=public --remove-service="$service" --permanent 2>/dev/null || true
    done
    
    firewall-cmd --reload
    echo "      -> Database services removed from public zone"
fi

echo ""
echo "========================================="
echo "  DATABASE HARDENING COMPLETE"
echo "========================================="
echo ""
echo "CRITICAL NEXT STEPS:"
echo "1. Test that applications can still connect to databases"
echo "2. Update application config files with new passwords"
echo "3. Check competition requirements for external database access"
echo "4. If external access is required, create specific firewall rules:"

if [[ "$MYSQL_INSTALLED" == "true" ]]; then
    echo "   MySQL: ufw allow from ALLOWED_IP to any port 3306"
fi
if [[ "$POSTGRES_INSTALLED" == "true" ]]; then
    echo "   PostgreSQL: ufw allow from ALLOWED_IP to any port 5432"
fi
if [[ "$MONGO_INSTALLED" == "true" ]]; then
    echo "   MongoDB: ufw allow from ALLOWED_IP to any port 27017"
fi

echo ""
echo "Monitoring commands:"
if [[ "$MYSQL_INSTALLED" == "true" ]]; then
    echo "  MySQL processes: mysqladmin -u root -p processlist"
    echo "  MySQL logs: tail -f /var/log/mysql/error.log"
fi
if [[ "$POSTGRES_INSTALLED" == "true" ]]; then
    echo "  PostgreSQL activity: sudo -u postgres psql -c \"SELECT * FROM pg_stat_activity;\""
    echo "  PostgreSQL logs: tail -f /var/log/postgresql/postgresql-*-main.log"
fi