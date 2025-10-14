#!/bin/bash
# ==============================================================
#  Skrypt automatycznej instalacji Homarr (Docker) w kontenerze LXC na Proxmox
#  Autor: ChatGPT (GPT-5)
# ==============================================================

set -e

# --- Konfiguracja ---
VMID=120
HOSTNAME="homarrr"
MEMORY=2048
CORES=2
DISK="8"
STORAGE="local-lvm"
TEMPLATE="local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"

echo "=== 🧱 Tworzenie kontenera LXC dla Homarr ==="

# --- Sprawdzenie czy obraz istnieje ---
if ! pveam list local | grep -q "debian-12-standard"; then
    echo "📦 Pobieranie szablonu Debian 12..."
    pveam update
    pveam download local debian-12-standard_12.12-1_amd64.tar.zst
fi

# --- Tworzenie kontenera ---
echo "🚀 Tworzenie kontenera LXC ($HOSTNAME)..."
pct create $VMID $TEMPLATE \
    --hostname $HOSTNAME \
    --cores $CORES \
    --memory $MEMORY \
    --swap 512 \
    --net0 name=eth0,bridge=vmbr0,ip=dhcp \
    --rootfs $STORAGE:$DISK \
    --unprivileged 1 \
    --features nesting=1 \
    --ostype debian \
    --start 1

# --- Instalacja Dockera i Homarr ---
echo "🐳 Instalacja Dockera i Homarr w kontenerze..."
pct exec $VMID -- bash -c "
    apt update && apt install -y ca-certificates curl gnupg lsb-release
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
      \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/debian \$(lsb_release -cs) stable\" \
      > /etc/apt/sources.list.d/docker.list
    apt update && apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
"

# --- Uruchomienie kontenera i pobranie Homarr ---
echo "🧩 Uruchamianie Homarr..."
pct exec $VMID -- bash -c "
    docker run -d \
        --name homarr \
        --restart unless-stopped \
        -p 7575:7575 \
        -v /opt/homarr/configs:/app/data/configs \
        -v /opt/homarr/icons:/app/public/icons \
        -v /var/run/docker.sock:/var/run/docker.sock \
        ghcr.io/ajnart/homarr:latest
"

echo "✅ Homarr został zainstalowany i uruchomiony w kontenerze $HOSTNAME"
echo "🌍 Otwórz w przeglądarce: http://<IP_KONTENERA>:7575"
echo "💡 Aby sprawdzić IP: pct exec $VMID -- hostname -I"
