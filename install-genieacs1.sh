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
apt install -y git curl gnupg apt-transport-https ca-certificates

# === Install Node.js 18 ===
echo -e "${GREEN}📦 Menginstal Node.js 18...${NC}"
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs build-essential

# === Install MongoDB ===
echo -e "${GREEN}📦 Menginstal MongoDB 4.4...${NC}"
# Modern way: download key to /usr/share/keyrings
curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-4.4.gpg

# Add repository with signed-by option
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-4.4.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" > /etc/apt/sources.list.d/mongodb-org-4.4.list

apt update && apt install -y mongodb-org
systemctl enable --now mongod
sleep 2

# === Install GenieACS (npm global) ===
echo -e "${GREEN}📦 Menginstal GenieACS versi terbaru (npm)...${NC}"
npm install -g genieacs

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
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-${svc}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
done

# === Enable & start all ===
systemctl daemon-reload
systemctl enable --now genieacs-{cwmp,nbi,fs,ui}
sleep 3

# === Tampilkan sukses instalasi ===
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}✅ Instalasi GenieACS by EGA CHANEL selesai.${NC}"
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

    echo -e "${YELLOW}⏸️ Menghentikan service GenieACS...${NC}"
    systemctl stop genieacs-{cwmp,nbi,fs,ui}

    echo -e "${YELLOW}🔄 Merestore database GenieACS...${NC}"
    mongorestore --drop --db genieacs /opt/genieacs-backup-full/genieacs

    echo -e "${YELLOW}▶️ Menjalankan kembali service GenieACS...${NC}"
    systemctl start genieacs-{cwmp,nbi,fs,ui}

    echo -e "${GREEN}============================================================${NC}"
    echo -e "${GREEN}✅ Restore parameter full berhasil dipasang.${NC}"
    echo -e "${YELLOW}Akses UI di: http://$local_ip:3000${NC}"
    echo -e "${GREEN}============================================================${NC}"
else
    echo -e "${YELLOW}⏭️ Restore parameter dilewati.${NC}"
    echo -e "${GREEN}============================================================${NC}"
fi
