#!/usr/bin/env bash
# create_lxc_for_docker.sh
# Tworzy LXC (privileged) z dostępem root + instaluje Docker
# Uruchom jako root na hoście Proxmox

set -e

##### ====== KONFIGURACJA (zmień wedle potrzeby) ======
VMID=120
HOSTNAME="homarr"                # nazwa hosta (małymi literami, bez spacji)
ROOT_PASSWORD="TwojeHaslo123!"   # ustaw swoje bezpieczne hasło
MEMORY=2048                      # MB
CORES=2
DISK=8                           # GB (tylko liczba, bez G)
STORAGE="local-lvm"              # storage dla rootfs (np. local-lvm lub local)
BRIDGE="vmbr0"
TEMPLATE_NAME="debian-12-standard_12.12-1_amd64.tar.zst"  # zgodne z "pveam available"
TEMPLATE_STORAGE="local"         # gdzie trzyma się templates (zazwyczaj 'local')
INSTALL_DOCKER_COMPOSE="yes"     # "yes" lub "no"
#######################################################

echo "=== START: Tworzenie kontenera LXC (VMID=$VMID, HOSTNAME=$HOSTNAME) ==="

# 1) sprawdź czy template jest dostępny w local cache, jeśli nie pobierz
if ! ls /var/lib/vz/template/cache/ | grep -qx "$TEMPLATE_NAME"; then
  echo "Szablon $TEMPLATE_NAME nie znaleziony w /var/lib/vz/template/cache/. Pobieram..."
  pveam update
  pveam download $TEMPLATE_STORAGE $TEMPLATE_NAME
else
  echo "Szablon $TEMPLATE_NAME jest dostępny."
fi

# 2) jeśli już istnieje kontener o tym VMID, przerwij
if pct status $VMID >/dev/null 2>&1; then
  echo "Błąd: kontener o VMID=$VMID już istnieje. Przerwij skrypt lub zmień VMID w konfiguracji."
  exit 1
fi

# 3) utwórz kontener (privileged), z nesting=1 (potrzebne dla Dockera)
echo "Tworzę kontener LXC..."
pct create $VMID ${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE_NAME} \
  --hostname "${HOSTNAME}" \
  --cores ${CORES} \
  --memory ${MEMORY} \
  --swap 512 \
  --net0 name=eth0,bridge=${BRIDGE},ip=dhcp \
  --rootfs ${STORAGE}:${DISK} \
  --unprivileged 0 \
  --features nesting=1,keyctl=1 \
  --ostype debian \
  --onboot 1 \
  --start 1 \
  --password "${ROOT_PASSWORD}"

echo "Kontener utworzony i wystartowany (jeśli start nie powiódł się, sprawdź 'pct status $VMID')."

# 4) Poczekaj chwilę na pełny start
sleep 3

# 5) zainstaluj podstawowe pakiety, openssh-server i Dockera wewnątrz kontenera
echo "Instaluję Dockera i openssh-server wewnątrz kontenera (może to potrwać)..."
pct exec $VMID -- bash -lc "
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https software-properties-common sudo
# openssh
apt-get install -y openssh-server
# Zezwól na logowanie root hasłem
sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config || true
sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config || true
systemctl restart ssh || true

# Instalacja Dockera (oficjalny skrypt)
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sh /tmp/get-docker.sh
usermod -aG docker root || true

# (opcjonalnie) docker compose plugin
if [ \"${INSTALL_DOCKER_COMPOSE}\" = \"yes\" ]; then
  apt-get install -y docker-compose-plugin || true
fi

# Utwórz przykładowe katalogi pod kontenery
mkdir -p /opt/homarr/appdata
chown -R root:root /opt/homarr
"

echo "Docker i (opcjonalnie) docker-compose zainstalowane."

# 6) wyświetl IP kontenera (pierwszy adres)
IP_ADDR=$(pct exec $VMID -- bash -lc "hostname -I 2>/dev/null | awk '{print \$1}'" || true)

echo "==== GOTOWE ===="
echo "Kontener VMID: $VMID"
echo "Hostname: $HOSTNAME"
echo "Root password: (ustawiłeś w skrypcie)"
if [ -n \"$IP_ADDR\" ]; then
  echo "IP kontenera: $IP_ADDR"
  echo "Możesz połączyć się po SSH: ssh root@$IP_ADDR"
else
  echo "Nie udało się automatycznie odczytać IP. Sprawdź: pct exec $VMID -- hostname -I"
fi

echo "Aby uruchomić Dockera wewnątrz kontenera użyj: pct exec $VMID -- docker ps"
echo "Jeśli chcesz, mogę przygotować gotowy docker run / docker-compose dla Homarr (powiadom mnie i podaj SECRET_ENCRYPTION_KEY)."
