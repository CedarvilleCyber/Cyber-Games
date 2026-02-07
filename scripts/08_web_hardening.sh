#!/bin/bash
#
# 08 - Web Server Hardening
# Secure Apache, Nginx, and web applications
# Usage: curl -sSL https://raw.githubusercontent.com/CedarvilleCyber/Cyber-Games/main/scripts/08_web_hardening.sh | sudo bash
#

set -euo pipefail

echo "========================================="
echo "  WEB SERVER HARDENING"
echo "========================================="

if [[ $(id -u) -ne 0 ]]; then
    echo "[!] Run this script as root."
    exit 1
fi

echo "[1] Scanning for web shells and backdoors"

# Common web directories
WEB_DIRS=("/var/www" "/var/www/html" "/usr/share/nginx/html" "/srv/http" "/home/*/public_html")

for dir in "${WEB_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        echo "    Scanning $dir for web shells..."
        
        # PHP web shells
        find "$dir" -name "*.php" -type f -exec grep -l "eval\|base64_decode\|system\|exec\|shell_exec\|passthru\|file_get_contents.*http\|curl_exec\|fsockopen" {} \; 2>/dev/null | while read file; do
            echo "      [!] SUSPICIOUS PHP: $file"
            grep -n "eval\|base64_decode\|system\|exec\|shell_exec\|passthru" "$file" | head -3
        done
        
        # Common web shell filenames
        find "$dir" -type f \( -name "*.php" -o -name "*.asp" -o -name "*.aspx" -o -name "*.jsp" \) | while read file; do
            filename=$(basename "$file")
            if [[ "$filename" =~ (shell|backdoor|cmd|hack|exploit|bypass|upload|webshell|c99|r57|b374k) ]]; then
                echo "      [!] SUSPICIOUS NAME: $file"
            fi
        done
        
        # Recently modified files (potential uploads)
        echo "      Recently modified files (last 24 hours):"
        find "$dir" -type f -mtime -1 -ls 2>/dev/null | head -5
    fi
done

echo ""
echo "[2] Apache hardening (if installed)"

if command -v apache2 &>/dev/null || command -v httpd &>/dev/null; then
    APACHE_CMD="apache2"
    APACHE_DIR="/etc/apache2"
    APACHE_SERVICE="apache2"
    
    # RHEL/CentOS detection
    if command -v httpd &>/dev/null && [[ ! -d /etc/apache2 ]]; then
        APACHE_CMD="httpd"
        APACHE_DIR="/etc/httpd"
        APACHE_SERVICE="httpd"
    fi
    
    echo "    -> Apache detected, applying hardening..."
    
    # Backup main config
    cp "$APACHE_DIR/apache2.conf" "$APACHE_DIR/apache2.conf.backup" 2>/dev/null || \
    cp "$APACHE_DIR/conf/httpd.conf" "$APACHE_DIR/conf/httpd.conf.backup" 2>/dev/null || true
    
    # Security configuration
    SECURITY_CONF="$APACHE_DIR/conf-available/security.conf"
    [[ ! -d "$APACHE_DIR/conf-available" ]] && SECURITY_CONF="$APACHE_DIR/conf.d/security.conf"
    
    cat > "$SECURITY_CONF" << 'APACHE_SECURITY'
# Apache Security Configuration

# Hide server information
ServerTokens Prod
ServerSignature Off

# Disable directory browsing
Options -Indexes

# Disable server-side includes
Options -Includes

# Disable CGI execution (uncomment if not needed)
# Options -ExecCGI

# Security headers
Header always set X-Content-Type-Options nosniff
Header always set X-Frame-Options DENY
Header always set X-XSS-Protection "1; mode=block"
Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
Header always set Content-Security-Policy "default-src 'self'"

# Disable trace method
TraceEnable off

# Limit request size (10MB)
LimitRequestBody 10485760

# Hide .htaccess files
<Files ".ht*">
    Require all denied
</Files>

# Hide backup and config files
<FilesMatch "\.(bak|config|sql|fla|psd|ini|log|sh|inc|swp|dist)$">
    Require all denied
</FilesMatch>

# Disable dangerous HTTP methods
<LimitExcept GET POST HEAD>
    Require all denied
</LimitExcept>
APACHE_SECURITY
    
    # Enable security config
    if [[ -d "$APACHE_DIR/conf-available" ]]; then
        a2enmod headers 2>/dev/null || true
        a2enconf security 2>/dev/null || true
    fi
    
    # Disable unnecessary modules
    DISABLE_MODULES=("autoindex" "status" "info" "userdir")
    for mod in "${DISABLE_MODULES[@]}"; do
        a2dismod "$mod" 2>/dev/null || true
    done
    
    # Test and restart Apache
    if $APACHE_CMD -t; then
        systemctl restart "$APACHE_SERVICE"
        echo "      -> Apache hardening applied successfully"
    else
        echo "      -> Apache configuration error, reverting..."
        rm -f "$SECURITY_CONF"
        systemctl restart "$APACHE_SERVICE"
    fi
else
    echo "    -> Apache not detected"
fi

echo ""
echo "[3] Nginx hardening (if installed)"

if command -v nginx &>/dev/null; then
    echo "    -> Nginx detected, applying hardening..."
    
    # Backup main config
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
    
    # Create security config
    cat > /etc/nginx/conf.d/security.conf << 'NGINX_SECURITY'
# Nginx Security Configuration

# Hide server information
server_tokens off;

# Security headers
add_header X-Frame-Options DENY always;
add_header X-Content-Type-Options nosniff always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
add_header Content-Security-Policy "default-src 'self'" always;

# Disable unwanted HTTP methods
if ($request_method !~ ^(GET|HEAD|POST)$) {
    return 405;
}

# Rate limiting
limit_req_zone $binary_remote_addr zone=login:10m rate=1r/s;
limit_req_zone $binary_remote_addr zone=api:10m rate=5r/s;

# File upload limits
client_max_body_size 10M;

# Hide backup and config files
location ~* \.(bak|config|sql|fla|psd|ini|log|sh|inc|swp|dist)$ {
    deny all;
}

# Hide dot files
location ~ /\. {
    deny all;
}
NGINX_SECURITY
    
    # Test and reload Nginx
    if nginx -t; then
        systemctl reload nginx
        echo "      -> Nginx hardening applied successfully"
    else
        echo "      -> Nginx configuration error, reverting..."
        rm -f /etc/nginx/conf.d/security.conf
        systemctl reload nginx
    fi
else
    echo "    -> Nginx not detected"
fi

echo ""
echo "[4] Web application security scan"

for dir in "${WEB_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        echo "    Checking $dir for common vulnerabilities..."
        
        # Check for default/weak passwords in config files
        find "$dir" -name "*.php" -o -name "*.conf" -o -name "*.cfg" | xargs grep -i "password.*=.*admin\|password.*=.*123\|password.*=.*password" 2>/dev/null | head -5
        
        # Check for database credentials in plain text
        find "$dir" -name "*.php" | xargs grep -l "mysql_connect\|mysqli_connect\|PDO" 2>/dev/null | while read file; do
            if grep -q "password.*=.*['\"].*['\"]" "$file"; then
                echo "      [!] Possible DB credentials in: $file"
            fi
        done
        
        # Check for upload directories
        find "$dir" -type d -name "*upload*" -o -name "*files*" | while read uploaddir; do
            echo "      Upload directory found: $uploaddir"
            # Check permissions
            ls -ld "$uploaddir"
            # Check for executable files in upload directories
            find "$uploaddir" -name "*.php" -o -name "*.sh" -o -name "*.py" 2>/dev/null | while read exec_file; do
                echo "        [!] Executable in upload dir: $exec_file"
            done
        done
    fi
done

echo ""
echo "[5] WordPress hardening (if detected)"

for dir in "${WEB_DIRS[@]}"; do
    if [[ -f "$dir/wp-config.php" ]]; then
        echo "    -> WordPress detected in $dir"
        
        # Check wp-config.php security
        if grep -q "table_prefix.*=.*wp_" "$dir/wp-config.php"; then
            echo "      [!] Default table prefix 'wp_' detected - consider changing"
        fi
        
        if grep -q "define.*DB_PASSWORD.*password\|define.*DB_PASSWORD.*123" "$dir/wp-config.php"; then
            echo "      [!] Weak database password detected"
        fi
        
        # Disable file editing
        if ! grep -q "DISALLOW_FILE_EDIT" "$dir/wp-config.php"; then
            sed -i "/<?php/a define('DISALLOW_FILE_EDIT', true);" "$dir/wp-config.php"
            echo "      -> Disabled WordPress file editing"
        fi
        
        # Check for suspicious plugins
        if [[ -d "$dir/wp-content/plugins" ]]; then
            find "$dir/wp-content/plugins" -name "*.php" | xargs grep -l "eval\|base64_decode\|exec\|system" 2>/dev/null | while read plugin; do
                echo "      [!] Suspicious plugin code: $plugin"
            done
        fi
        
        # Remove default themes/plugins if not needed
        for default in "twentytwenty" "twentytwentyone" "twentytwentytwo" "hello-dolly"; do
            if [[ -d "$dir/wp-content/themes/$default" ]] || [[ -d "$dir/wp-content/plugins/$default" ]]; then
                echo "      Default theme/plugin found: $default (consider removing if unused)"
            fi
        done
        
        # Secure wp-config.php permissions
        chmod 600 "$dir/wp-config.php"
        echo "      -> Secured wp-config.php permissions"
    fi
done

echo ""
echo "[6] SSL/TLS configuration check"

if ss -tulpn | grep -q ":443"; then
    echo "    -> HTTPS detected, checking configuration..."
    
    # Check for SSL certificates
    for cert_dir in "/etc/ssl/certs" "/etc/letsencrypt/live" "/etc/nginx/ssl" "/etc/apache2/ssl"; do
        if [[ -d "$cert_dir" ]]; then
            echo "      SSL certificates found in: $cert_dir"
            find "$cert_dir" -name "*.crt" -o -name "*.pem" | head -3
        fi
    done
    
    # Basic SSL test (if openssl available)
    if command -v openssl &>/dev/null; then
        echo "      Testing SSL connection to localhost..."
        timeout 5 openssl s_client -connect localhost:443 -servername localhost 2>/dev/null | grep -E "Verify return code|subject=" || echo "        SSL test failed or timed out"
    fi
else
    echo "    -> No HTTPS service detected"
fi

echo ""
echo "========================================="
echo "  WEB SERVER HARDENING COMPLETE"
echo "========================================="
echo ""
echo "REVIEW REQUIRED:"
echo "1. Check all web applications still function correctly"
echo "2. Review any suspicious files found above"
echo "3. Test that scoring services still work"
echo "4. Consider removing/securing any upload directories"
echo "5. Update any weak passwords found in config files"
echo ""
echo "Monitoring commands:"
echo "  Apache access log: tail -f /var/log/apache2/access.log"
echo "  Apache error log: tail -f /var/log/apache2/error.log"
echo "  Nginx access log: tail -f /var/log/nginx/access.log"
echo "  Nginx error log: tail -f /var/log/nginx/error.log"