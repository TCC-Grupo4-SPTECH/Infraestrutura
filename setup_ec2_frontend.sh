#!/bin/bash

set -Eeuo pipefail

LOG_FILE="/var/log/setup_ec2_frontend.log"
exec > >(tee -a "$LOG_FILE" | logger -t setup_ec2_frontend -s 2>/dev/console) 2>&1

NODE_MAJOR_VERSION="20"
APP_ROOT="/var/www/angular"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log "Starting frontend EC2 setup"

if command -v apt-get >/dev/null 2>&1; then
    log "Detected Debian/Ubuntu package manager"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y ca-certificates curl gnupg nginx git unzip build-essential

    curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR_VERSION}.x" | bash -
    apt-get install -y nodejs
    rm -f /etc/nginx/sites-enabled/default
elif command -v dnf >/dev/null 2>&1; then
    log "Detected DNF package manager"
    dnf upgrade -y
    dnf install -y ca-certificates nginx git unzip gcc gcc-c++ make

    curl -fsSL "https://rpm.nodesource.com/setup_${NODE_MAJOR_VERSION}.x" | bash -
    dnf install -y nodejs
elif command -v yum >/dev/null 2>&1; then
    log "Detected YUM package manager"
    yum update -y
    yum install -y ca-certificates nginx git unzip gcc gcc-c++ make

    curl -fsSL "https://rpm.nodesource.com/setup_${NODE_MAJOR_VERSION}.x" | bash -
    yum install -y nodejs
else
    log "Unsupported package manager"
    exit 1
fi

log "Installing Angular CLI"
npm install --global @angular/cli

log "Creating Angular application directory"
mkdir -p "$APP_ROOT"
chown -R nginx:nginx "$APP_ROOT" 2>/dev/null || true

log "Configuring Nginx for an Angular single-page application"
mkdir -p /etc/nginx/conf.d
cat > /etc/nginx/conf.d/angular.conf <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    root $APP_ROOT;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
EOF

nginx -t
systemctl enable nginx
systemctl restart nginx

log "Frontend environment ready"
node --version
npm --version
ng version
log "Deploy the Angular build output to $APP_ROOT"
