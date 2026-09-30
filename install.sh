#!/bin/sh

set -eu

# ============================================================
# PostgreSQL 14.24 + pgAdmin Installer
# macOS / Linux
#
# Default ports:
#   PostgreSQL: 5432
#   pgAdmin:    5050
#
# Override example:
#   curl -fsSL <URL> | POSTGRES_PORT=5433 sh
# ============================================================

INSTALL_DIR="${INSTALL_DIR:-$HOME/postgres14-school}"

POSTGRES_VERSION="14.24"

POSTGRES_PORT="${POSTGRES_PORT:-5432}"
PGADMIN_PORT="${PGADMIN_PORT:-5050}"

POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-postgres}"

PGADMIN_EMAIL="${PGADMIN_EMAIL:-admin@localhost.com}"
PGADMIN_PASSWORD="${PGADMIN_PASSWORD:-admin}"


# ------------------------------------------------------------
# Colors
# ------------------------------------------------------------

if [ -t 1 ]; then
    BOLD='\033[1m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    RED='\033[0;31m'
    CYAN='\033[0;36m'
    RESET='\033[0m'
else
    BOLD=''
    GREEN=''
    YELLOW=''
    RED=''
    CYAN=''
    RESET=''
fi


info() {
    printf "${CYAN}==>${RESET} %s\n" "$1"
}

success() {
    printf "${GREEN}==>${RESET} %s\n" "$1"
}

warn() {
    printf "${YELLOW}==>${RESET} %s\n" "$1"
}

fail() {
    printf "\n${RED}ERROR:${RESET} %s\n\n" "$1"
    exit 1
}


printf "\n${BOLD}PostgreSQL %s + pgAdmin Installer${RESET}\n\n" "$POSTGRES_VERSION"


# ------------------------------------------------------------
# Detect operating system
# ------------------------------------------------------------

case "$(uname -s)" in
    Darwin)
        OS="macos"
        ;;
    Linux)
        OS="linux"
        ;;
    *)
        fail "Bu script yalnızca macOS ve Linux destekliyor."
        ;;
esac

success "İşletim sistemi: $OS"


# ------------------------------------------------------------
# Validate port
# ------------------------------------------------------------

validate_port() {
    port="$1"

    case "$port" in
        ''|*[!0-9]*)
            fail "Geçersiz port: $port"
            ;;
    esac

    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        fail "Port 1-65535 arasında olmalı: $port"
    fi
}

validate_port "$POSTGRES_PORT"
validate_port "$PGADMIN_PORT"


# ------------------------------------------------------------
# Check Docker
# ------------------------------------------------------------

if ! command -v docker >/dev/null 2>&1; then
    printf "\n"
    warn "Docker kurulu değil."

    if [ "$OS" = "macos" ]; then
        printf "\nDocker Desktop kurman gerekiyor:\n"
        printf "https://www.docker.com/products/docker-desktop/\n"

        if command -v brew >/dev/null 2>&1; then
            printf "\nHomebrew kullanıyorsan:\n"
            printf "  brew install --cask docker\n"
        fi
    else
        printf "\nDocker Engine kurman gerekiyor:\n"
        printf "https://docs.docker.com/engine/install/\n"
    fi

    printf "\nDocker kurulduktan sonra komutu tekrar çalıştır.\n\n"
    exit 1
fi

success "Docker bulundu."


# ------------------------------------------------------------
# Check Docker daemon
# ------------------------------------------------------------

if ! docker info >/dev/null 2>&1; then
    if [ "$OS" = "macos" ]; then
        fail "Docker kurulu fakat çalışmıyor. Docker Desktop'ı açıp tamamen başlamasını bekle."
    else
        fail "Docker kurulu fakat daemon çalışmıyor. 'sudo systemctl start docker' komutunu deneyebilirsin."
    fi
fi

success "Docker çalışıyor."


# ------------------------------------------------------------
# Detect Docker Compose
# ------------------------------------------------------------

if docker compose version >/dev/null 2>&1; then
    COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE="docker-compose"
else
    fail "Docker Compose bulunamadı."
fi

success "Docker Compose bulundu."


# ------------------------------------------------------------
# Port detection
# ------------------------------------------------------------

port_in_use() {
    port="$1"

    # Docker-published ports
    if docker ps \
        --filter "publish=$port" \
        --format '{{.ID}}' 2>/dev/null |
        grep -q .; then
        return 0
    fi

    # Linux
    if command -v ss >/dev/null 2>&1; then
        if ss -ltn 2>/dev/null |
            awk '{print $4}' |
            grep -Eq "(^|:)$port$"; then
            return 0
        fi
    fi

    # macOS / Linux fallback
    if command -v lsof >/dev/null 2>&1; then
        if lsof -nP \
            -iTCP:"$port" \
            -sTCP:LISTEN >/dev/null 2>&1; then
            return 0
        fi
    fi

    # Last fallback
    if command -v nc >/dev/null 2>&1; then
        if nc -z 127.0.0.1 "$port" >/dev/null 2>&1; then
            return 0
        fi
    fi

    return 1
}


show_port_owner() {
    port="$1"

    docker_match="$(
        docker ps \
            --filter "publish=$port" \
            --format 'Docker container: {{.Names}} — {{.Ports}}' \
            2>/dev/null || true
    )"

    if [ -n "$docker_match" ]; then
        printf "%s\n" "$docker_match"
        return
    fi

    if command -v lsof >/dev/null 2>&1; then
        lsof -nP \
            -iTCP:"$port" \
            -sTCP:LISTEN 2>/dev/null |
            sed -n '1,5p' || true
        return
    fi

    if command -v ss >/dev/null 2>&1; then
        ss -ltnp 2>/dev/null |
            grep -E "(^|:)$port([[:space:]]|$)" |
            head -5 || true
    fi
}


check_required_port() {
    port="$1"
    name="$2"
    variable="$3"

    if port_in_use "$port"; then
        printf "\n"
        printf "${RED}${BOLD}%s portu (%s) zaten kullanımda.${RESET}\n" \
            "$name" "$port"

        printf "\n"

        show_port_owner "$port"

        printf "\n"
        printf "Kurulum hiçbir değişiklik yapılmadan durduruldu.\n"

        printf "\nFarklı bir portla çalıştırmak istersen:\n"
        printf "  curl -fsSL <install.sh URL> | %s=XXXX sh\n" \
            "$variable"

        printf "\nÖrnek:\n"
        printf "  curl -fsSL <install.sh URL> | %s=%s sh\n\n" \
            "$variable" \
            "$((port + 1))"

        exit 1
    fi
}


info "Portlar kontrol ediliyor..."

check_required_port \
    "$POSTGRES_PORT" \
    "PostgreSQL" \
    "POSTGRES_PORT"

check_required_port \
    "$PGADMIN_PORT" \
    "pgAdmin" \
    "PGADMIN_PORT"

success "PostgreSQL portu müsait: $POSTGRES_PORT"
success "pgAdmin portu müsait: $PGADMIN_PORT"


# ------------------------------------------------------------
# Create installation directory
# ------------------------------------------------------------

mkdir -p "$INSTALL_DIR"

info "Kurulum klasörü: $INSTALL_DIR"


# ------------------------------------------------------------
# Create compose.yml
# ------------------------------------------------------------

cat > "$INSTALL_DIR/compose.yml" <<EOF
services:

  postgres:
    image: postgres:${POSTGRES_VERSION}
    container_name: school-postgres
    restart: unless-stopped

    environment:
      POSTGRES_USER: \${POSTGRES_USER}
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
      POSTGRES_DB: \${POSTGRES_DB}

    ports:
      - "\${POSTGRES_PORT}:5432"

    volumes:
      - postgres_data:/var/lib/postgresql/data

    healthcheck:
      test:
        - CMD-SHELL
        - pg_isready -U \${POSTGRES_USER} -d \${POSTGRES_DB}
      interval: 5s
      timeout: 5s
      retries: 20


  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: school-pgadmin
    restart: unless-stopped

    environment:
      PGADMIN_DEFAULT_EMAIL: \${PGADMIN_EMAIL}
      PGADMIN_DEFAULT_PASSWORD: \${PGADMIN_PASSWORD}

    ports:
      - "\${PGADMIN_PORT}:80"

    volumes:
      - pgadmin_data:/var/lib/pgadmin
      - ./servers.json:/pgadmin4/servers.json:ro

    depends_on:
      postgres:
        condition: service_healthy


volumes:
  postgres_data:
  pgadmin_data:
EOF


# ------------------------------------------------------------
# Create .env
# ------------------------------------------------------------

cat > "$INSTALL_DIR/.env" <<EOF
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=${POSTGRES_DB}
POSTGRES_PORT=${POSTGRES_PORT}

PGADMIN_EMAIL=${PGADMIN_EMAIL}
PGADMIN_PASSWORD=${PGADMIN_PASSWORD}
PGADMIN_PORT=${PGADMIN_PORT}
EOF


# ------------------------------------------------------------
# Create pgAdmin predefined server
# ------------------------------------------------------------

cat > "$INSTALL_DIR/servers.json" <<EOF
{
  "Servers": {
    "1": {
      "Name": "PostgreSQL 14",
      "Group": "Servers",
      "Host": "postgres",
      "Port": 5432,
      "MaintenanceDB": "${POSTGRES_DB}",
      "Username": "${POSTGRES_USER}",
      "SSLMode": "prefer"
    }
  }
}
EOF

success "Yapılandırma dosyaları oluşturuldu."


# ------------------------------------------------------------
# Enter installation directory
# ------------------------------------------------------------

cd "$INSTALL_DIR"


# ------------------------------------------------------------
# Pull images
# ------------------------------------------------------------

info "Docker image'ları indiriliyor..."

if ! $COMPOSE -f compose.yml pull; then
    fail "Docker image'ları indirilemedi. İnternet bağlantını ve Docker durumunu kontrol et."
fi


# ------------------------------------------------------------
# Start containers
# ------------------------------------------------------------

info "PostgreSQL ve pgAdmin başlatılıyor..."

if ! $COMPOSE -f compose.yml up -d; then
    printf "\n"
    warn "Container'lar başlatılırken hata oluştu."

    printf "\nOluşturulan container'lar kapatılıyor...\n"

    # Volumes are intentionally preserved.
    $COMPOSE -f compose.yml down >/dev/null 2>&1 || true

    printf "\nLogları görmek için:\n"
    printf "  cd %s\n" "$INSTALL_DIR"
    printf "  %s -f compose.yml logs\n\n" "$COMPOSE"

    exit 1
fi


# ------------------------------------------------------------
# Wait for PostgreSQL
# ------------------------------------------------------------

info "PostgreSQL'in hazır olması bekleniyor..."

i=0
ready=0

while [ "$i" -lt 30 ]; do
    if docker exec school-postgres \
        pg_isready \
        -U "$POSTGRES_USER" \
        -d "$POSTGRES_DB" >/dev/null 2>&1; then

        ready=1
        break
    fi

    i=$((i + 1))
    sleep 1
done


if [ "$ready" -ne 1 ]; then
    printf "\n"
    warn "PostgreSQL 30 saniye içerisinde hazır hale gelemedi."

    printf "\nPostgreSQL logları:\n\n"

    $COMPOSE -f compose.yml logs --tail=30 postgres || true

    printf "\n"

    exit 1
fi

success "PostgreSQL hazır."


# ------------------------------------------------------------
# Final status
# ------------------------------------------------------------

printf "\n"
printf "${GREEN}${BOLD}✓ Kurulum tamamlandı!${RESET}\n"
printf "\n"

printf "${BOLD}PostgreSQL${RESET}\n"
printf "  Host:     localhost\n"
printf "  Port:     %s\n" "$POSTGRES_PORT"
printf "  Database: %s\n" "$POSTGRES_DB"
printf "  Username: %s\n" "$POSTGRES_USER"
printf "  Password: %s\n" "$POSTGRES_PASSWORD"

printf "\n"

printf "${BOLD}Bağlantı URL'si${RESET}\n"
printf "  postgresql://%s:%s@localhost:%s/%s\n" \
    "$POSTGRES_USER" \
    "$POSTGRES_PASSWORD" \
    "$POSTGRES_PORT" \
    "$POSTGRES_DB"

printf "\n"

printf "${BOLD}pgAdmin${RESET}\n"
printf "  URL:      http://localhost:%s\n" "$PGADMIN_PORT"
printf "  Email:    %s\n" "$PGADMIN_EMAIL"
printf "  Password: %s\n" "$PGADMIN_PASSWORD"

printf "\n"

printf "${BOLD}pgAdmin -> PostgreSQL${RESET}\n"
printf "  Host:     postgres\n"
printf "  Port:     5432\n"
printf "  Database: %s\n" "$POSTGRES_DB"
printf "  Username: %s\n" "$POSTGRES_USER"
printf "  Password: %s\n" "$POSTGRES_PASSWORD"

printf "\n"

printf "${BOLD}Container durumları${RESET}\n\n"

$COMPOSE -f compose.yml ps

printf "\n"

printf "${BOLD}Kurulum dizini${RESET}\n"
printf "  %s\n" "$INSTALL_DIR"

printf "\n"

printf "${BOLD}Durdurmak için${RESET}\n"
printf "  cd %s && %s -f compose.yml down\n" \
    "$INSTALL_DIR" \
    "$COMPOSE"

printf "\n"

printf "${BOLD}Tekrar başlatmak için${RESET}\n"
printf "  cd %s && %s -f compose.yml up -d\n" \
    "$INSTALL_DIR" \
    "$COMPOSE"

printf "\n"

printf "${BOLD}Verileri tamamen silmek için${RESET}\n"
printf "  cd %s && %s -f compose.yml down -v\n" \
    "$INSTALL_DIR" \
    "$COMPOSE"

printf "\n"
