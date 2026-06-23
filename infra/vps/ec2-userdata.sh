#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# EC2 User Data: VPS Setup Script
# Runs as root on first boot.
# Sets up: OS hardening + Node.js + Python + PM2 + nginx + Certbot + app
#
# The ${elastic_ip} placeholder is replaced by Terraform templatefile().
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail
exec > /var/log/userdata.log 2>&1

ELASTIC_IP="${elastic_ip}"
NIP_DOMAIN="${elastic_ip}.nip.io"
APP_DIR="/opt/devops-app"
APP_USER="appuser"

echo "=== Starting VPS setup for domain: $NIP_DOMAIN ==="

# ── 1. System update ──────────────────────────────────────────────────────────
apt-get update -y
apt-get upgrade -y
apt-get install -y curl wget git ufw fail2ban nginx certbot python3-certbot-nginx \
  python3 python3-pip python3-venv software-properties-common

# ── 2. Firewall (ufw) — deny all in, allow SSH/HTTP/HTTPS ────────────────────
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP (Certbot HTTP challenge + redirect)
ufw allow 443/tcp   # HTTPS
ufw --force enable
echo "ufw configured."

# ── 3. SSH hardening ──────────────────────────────────────────────────────────
# Disable password auth — SSH key only
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
systemctl reload sshd
echo "SSH hardening applied."

# ── 4. fail2ban — ban IPs that fail SSH auth ──────────────────────────────────
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5

[sshd]
enabled  = true
port     = ssh
logpath  = /var/log/auth.log
maxretry = 3
EOF
systemctl enable fail2ban
systemctl start fail2ban
echo "fail2ban configured."

# ── 5. Create non-root app user ───────────────────────────────────────────────
useradd --system --create-home --shell /bin/bash "$APP_USER" || true

# ── 6. Node.js 20 + PM2 ───────────────────────────────────────────────────────
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
npm install -g pm2
echo "Node.js $(node --version) + PM2 installed."

# ── 7. Python + backend dependencies ─────────────────────────────────────────
python3 -m pip install --upgrade pip
echo "Python $(python3 --version) installed."

# ── 8. Clone / pull application code ─────────────────────────────────────────
mkdir -p "$APP_DIR"
chown "$APP_USER:$APP_USER" "$APP_DIR"

# Note: In real usage, clone your forked repo here.
# For the assignment demo, we clone the app directly.
# Replace GITHUB_REPO with your actual fork URL.
GITHUB_REPO="https://github.com/REPLACE_WITH_GITHUB_ORG/DevOps-Assignment.git"

sudo -u "$APP_USER" git clone "$GITHUB_REPO" "$APP_DIR/app" || \
  sudo -u "$APP_USER" bash -c "cd '$APP_DIR/app' && git pull"

# ── 9. Backend: install deps + create systemd via PM2 ─────────────────────────
BACKEND_DIR="$APP_DIR/app/backend"
sudo -u "$APP_USER" bash -c "
  cd '$BACKEND_DIR'
  python3 -m venv venv
  source venv/bin/activate
  pip install -r requirements.txt
"

# Create PM2 ecosystem config
cat > "$APP_DIR/ecosystem.config.js" << EOF
module.exports = {
  apps: [
    {
      name: 'backend',
      cwd: '${BACKEND_DIR}',
      interpreter: '${BACKEND_DIR}/venv/bin/python3',
      script: '${BACKEND_DIR}/venv/bin/uvicorn',
      args: 'app.main:app --host 127.0.0.1 --port 8000',
      env: {
        PORT: '8000',
        ENVIRONMENT: 'vps'
      },
      watch: false,
      restart_delay: 3000,
      max_restarts: 10
    },
    {
      name: 'frontend',
      cwd: '${APP_DIR}/app/frontend',
      script: 'npm',
      args: 'run start -- --port 3001',
      env: {
        NODE_ENV: 'production',
        PORT: '3001',
        NEXT_PUBLIC_API_URL: 'https://${NIP_DOMAIN}'
      },
      watch: false,
      restart_delay: 3000,
      max_restarts: 10
    }
  ]
};
EOF
chown "$APP_USER:$APP_USER" "$APP_DIR/ecosystem.config.js"

# ── 10. Frontend: install deps + build ────────────────────────────────────────
FRONTEND_DIR="$APP_DIR/app/frontend"
sudo -u "$APP_USER" bash -c "
  cd '$FRONTEND_DIR'
  npm ci
  NEXT_PUBLIC_API_URL='https://${NIP_DOMAIN}' npm run build
"

# ── 11. Start apps with PM2 ───────────────────────────────────────────────────
sudo -u "$APP_USER" pm2 start "$APP_DIR/ecosystem.config.js"
sudo -u "$APP_USER" pm2 save

# Configure PM2 to auto-start on reboot
env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd \
  -u "$APP_USER" --hp "/home/$APP_USER" | bash
echo "PM2 apps started."

# ── 12. nginx config ──────────────────────────────────────────────────────────
cat > /etc/nginx/sites-available/devops-app << 'NGINXEOF'
server {
    listen 80;
    server_name NIPSUB_PLACEHOLDER;

    # Let Certbot handle HTTPS upgrade; for now serve via HTTP
    # Certbot will add the HTTPS server block automatically.

    # Backend API — proxy to uvicorn on 8000
    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 30s;
        proxy_read_timeout 30s;
    }

    # Frontend — proxy to Next.js on 3001
    location / {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_connect_timeout 60s;
        proxy_read_timeout 60s;
    }
}
NGINXEOF

# Replace placeholder with actual nip.io domain
sed -i "s/NIPSUB_PLACEHOLDER/${NIP_DOMAIN}/g" /etc/nginx/sites-available/devops-app

# Enable site
ln -sf /etc/nginx/sites-available/devops-app /etc/nginx/sites-enabled/devops-app
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx
echo "nginx configured."

# ── 13. Certbot — Let's Encrypt TLS via nip.io ────────────────────────────────
# nip.io resolves <ip>.nip.io → <ip>, so Certbot's HTTP challenge works
# without a real domain purchase.
certbot --nginx \
  --non-interactive \
  --agree-tos \
  --email "admin@${NIP_DOMAIN}" \
  -d "${NIP_DOMAIN}" \
  --redirect  # Automatically add HTTP→HTTPS redirect

echo "Certbot TLS configured."

# ── 14. Auto-renew cron ───────────────────────────────────────────────────────
echo "0 3 * * * root certbot renew --quiet --post-hook 'systemctl reload nginx'" \
  > /etc/cron.d/certbot-renew

echo "=== VPS setup complete ==="
echo "=== App available at: https://${NIP_DOMAIN} ==="
