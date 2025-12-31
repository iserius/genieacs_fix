#!/bin/bash
set -e

# === Warna ===
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
local_ip=$(hostname -I | awk '{print $1}')

# === Banner ===
clear
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}   ¶¶¶¶¶¶¶+ ¶¶¶¶¶¶+  ¶¶¶¶¶+      ¶¶¶¶¶¶+¶¶+  ¶¶+ ¶¶¶¶¶+     ${NC}"
echo -e "${GREEN}   ¶¶+----+¶¶+---¶¶+¶¶+--¶¶+    ¶¶+----+¶¶¶  ¶¶¶¶¶+--¶¶+    ${NC}"
echo -e "${GREEN}   ¶¶¶¶¶¶¶+¶¶¶   ¶¶¶¶¶¶¶¶¶¶¶    ¶¶¶     ¶¶¶¶¶¶¶¶¶¶¶¶¶¶¶¶    ${NC}"
echo -e "${GREEN}   +----¶¶¶¶¶¶__ ¶¶¶¶¶+--¶¶¶    ¶¶¶     ¶¶+--¶¶¶¶¶+--¶¶¶    ${NC}"
echo -e "${GREEN}   ¶¶¶¶¶¶¶¶+¶¶¶¶¶¶++¶¶¶  ¶¶¶    +¶¶¶¶¶¶+¶¶¶  ¶¶¶¶¶¶  ¶¶¶    ${NC}"
echo -e "${GREEN}   +------+ +--ØØ-+ +-+  +-+     +-----++-+  +-++-+  +-+    ${NC}"
echo -e "${YELLOW}        GenieACS Auto Installer by EGA CHANEL ${NC}"
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}Ubuntu $(lsb_release -d | cut -f2) | IP: ${local_ip}${NC}"
echo -e "${GREEN}============================================================${NC}"
sleep 2

# === Konfirmasi ===
echo -ne "${YELLOW}Lanjutkan instalasi GenieACS resmi (fresh)? (y/n): ${NC}"
read confirm
[ "$confirm" != "y" ] && echo -e "${RED}Dibatalkan.${NC}" && exit 1

# === Update & install dependensi ===
echo -e "${GREEN}📦 Memperbarui sistem & memasang dependensi...${NC}"
apt update -y && apt upgrade -y
apt install -y git curl gnupg apt-transport-https ca-certificates software-properties-common

# === Install Node.js 20 LTS ===
echo -e "${GREEN}📦 Menginstal Node.js 20 LTS...${NC}"
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs build-essential

# Verifikasi Node.js version
NODE_VERSION=$(node -v)
echo -e "${GREEN}✅ Node.js ${NODE_VERSION} berhasil diinstall${NC}"

# === Deteksi versi Ubuntu dan install MongoDB ===
UBUNTU_CODENAME=$(lsb_release -cs)
echo -e "${GREEN}📦 Menginstal MongoDB 7.0 untuk Ubuntu ${UBUNTU_CODENAME}...${NC}"

# Download dan install GPG key
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg

# Add repository berdasarkan versi Ubuntu
case "$UBUNTU_CODENAME" in
    jammy)
        echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" > /etc/apt/sources.list.d/mongodb-org-7.0.list
        ;;
    focal)
        echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/7.0 multiverse" > /etc/apt/sources.list.d/mongodb-org-7.0.list
        ;;
    noble)
        echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/7.0 multiverse" > /etc/apt/sources.list.d/mongodb-org-7.0.list
        ;;
    *)
        echo -e "${YELLOW}⚠️  Versi Ubuntu tidak dikenali, mencoba jammy repository...${NC}"
        echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" > /etc/apt/sources.list.d/mongodb-org-7.0.list
        ;;
esac

apt update && apt install -y mongodb-org

# Pin MongoDB version untuk mencegah auto-upgrade
echo "mongodb-org hold" | dpkg --set-selections
echo "mongodb-org-database hold" | dpkg --set-selections
echo "mongodb-org-server hold" | dpkg --set-selections
echo "mongodb-mongosh hold" | dpkg --set-selections
echo "mongodb-org-mongos hold" | dpkg --set-selections
echo "mongodb-org-tools hold" | dpkg --set-selections

systemctl enable --now mongod
sleep 2

# Verifikasi MongoDB berjalan
if systemctl is-active --quiet mongod; then
    MONGO_VERSION=$(mongod --version | head -n 1)
    echo -e "${GREEN}✅ MongoDB berhasil diinstall dan berjalan${NC}"
    echo -e "${GREEN}   ${MONGO_VERSION}${NC}"
else
    echo -e "${RED}❌ MongoDB gagal berjalan, periksa logs dengan: journalctl -u mongod${NC}"
fi

# === Install GenieACS (npm global) ===
echo -e "${GREEN}📦 Menginstal GenieACS versi terbaru (npm)...${NC}"
npm install -g genieacs

# Verifikasi GenieACS version
GENIEACS_VERSION=$(genieacs-cwmp --version 2>&1 || echo "installed")
echo -e "${GREEN}✅ GenieACS berhasil diinstall${NC}"

# === Membuat user & direktori ===
useradd --system --no-create-home --user-group genieacs || true
mkdir -p /opt/genieacs/ext /var/log/genieacs
chown -R genieacs:genieacs /opt/genieacs /var/log/genieacs

# === File environment ===
cat << EOF > /opt/genieacs/genieacs.env
GENIEACS_EXT_DIR=/opt/genieacs/ext
GENIEACS_UI_JWT_SECRET=secret
EOF
chown genieacs:genieacs /opt/genieacs/genieacs.env
chmod 600 /opt/genieacs/genieacs.env

# === Systemd services ===
echo -e "${GREEN}📦 Membuat service systemd...${NC}"
for svc in cwmp nbi fs ui; do
cat << EOF > /etc/systemd/system/genieacs-${svc}.service
[Unit]
Description=GenieACS ${svc^^}
After=network.target mongod.service
Requires=mongod.service

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-${svc}
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
done

# === Enable & start all ===
systemctl daemon-reload
systemctl enable --now genieacs-{cwmp,nbi,fs,ui}
sleep 3

# === Verifikasi services ===
echo -e "${GREEN}📦 Memeriksa status services...${NC}"
ALL_OK=true
for svc in cwmp nbi fs ui; do
    if systemctl is-active --quiet genieacs-${svc}; then
        echo -e "${GREEN}✅ genieacs-${svc} berjalan${NC}"
    else
        echo -e "${RED}❌ genieacs-${svc} gagal berjalan${NC}"
        ALL_OK=false
    fi
done

# === Tampilkan sukses instalasi ===
echo -e "${GREEN}============================================================${NC}"
if [ "$ALL_OK" = true ]; then
    echo -e "${GREEN}✅ Instalasi GenieACS by EGA CHANEL selesai.${NC}"
else
    echo -e "${YELLOW}⚠️  Instalasi selesai dengan beberapa warning${NC}"
    echo -e "${YELLOW}   Periksa logs: journalctl -u genieacs-cwmp${NC}"
fi
echo -e "${YELLOW}Akses UI di: http://$local_ip:3000${NC}"
echo -e "${GREEN}============================================================${NC}"

# === OPSI RESTORE PARAMETER FULL ===
echo -ne "${YELLOW}Apakah Anda ingin menginstall parameter full dari EGA CHANEL? (y/n): ${NC}"
read restore_confirm

if [ "$restore_confirm" == "y" ]; then
    echo -e "${GREEN}📦 Mengunduh dan menginstall parameter full...${NC}"
    cd /opt
    rm -rf /opt/genieacs-backup-full
    git clone https://github.com/egachanel2626-sketch/genieacs-backup-full.git

    if [ ! -d "/opt/genieacs-backup-full/genieacs" ]; then
        echo -e "${RED}❌ Direktori backup tidak ditemukan!${NC}"
        exit 1
    fi

    echo -e "${YELLOW}⏸️  Menghentikan service GenieACS...${NC}"
    systemctl stop genieacs-{cwmp,nbi,fs,ui}

    echo -e "${YELLOW}🔄 Merestore database GenieACS...${NC}"
    mongorestore --drop --db genieacs /opt/genieacs-backup-full/genieacs

    echo -e "${YELLOW}▶️  Menjalankan kembali service GenieACS...${NC}"
    systemctl start genieacs-{cwmp,nbi,fs,ui}
    sleep 3

    # Verifikasi services setelah restore
    echo -e "${GREEN}📦 Memeriksa status services setelah restore...${NC}"
    for svc in cwmp nbi fs ui; do
        if systemctl is-active --quiet genieacs-${svc}; then
            echo -e "${GREEN}✅ genieacs-${svc} berjalan${NC}"
        else
            echo -e "${RED}❌ genieacs-${svc} gagal berjalan${NC}"
        fi
    done

    echo -e "${GREEN}============================================================${NC}"
    echo -e "${GREEN}✅ Restore parameter full berhasil dipasang.${NC}"
    echo -e "${YELLOW}Akses UI di: http://$local_ip:3000${NC}"
    echo -e "${GREEN}============================================================${NC}"
else
    echo -e "${YELLOW}⏭️  Restore parameter dilewati.${NC}"
    echo -e "${GREEN}============================================================${NC}"
fi

echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}Informasi Penting:${NC}"
echo -e "${YELLOW}• GenieACS UI: http://$local_ip:3000${NC}"
echo -e "${YELLOW}• GenieACS CWMP (TR-069): http://$local_ip:7547${NC}"
echo -e "${YELLOW}• GenieACS NBI API: http://$local_ip:7557${NC}"
echo -e "${YELLOW}• GenieACS FS: http://$local_ip:7567${NC}"
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}Perintah berguna:${NC}"
echo -e "${YELLOW}• Cek status: systemctl status genieacs-{cwmp,nbi,fs,ui}${NC}"
echo -e "${YELLOW}• Restart: systemctl restart genieacs-{cwmp,nbi,fs,ui}${NC}"
echo -e "${YELLOW}• Logs: journalctl -u genieacs-cwmp -f${NC}"
echo -e "${GREEN}============================================================${NC}"
