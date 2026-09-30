#!/bin/sh

set -eu

INSTALL_DIR="${HOME}/postgres14-school"

POSTGRES_VERSION="14.24"
POSTGRES_PORT="5432"

PGADMIN_PORT="5050"
PGADMIN_EMAIL="admin@localhost.com"
PGADMIN_PASSWORD="admin"

POSTGRES_USER="postgres"
POSTGRES_PASSWORD="postgres"
POSTGRES_DB="postgres"

bold='\033[1m'
green='\033[0;32m'
yellow='\033[0;33m'
red='\033[0;31m'
reset='\033[0m'

info() {
    printf "${green}==>${reset} %s\n" "$1"
}

warn() {
    printf "${yellow}==>${reset} %s\n" "$1"
}

fail() {
    printf "${red}ERROR:${reset} %s\n" "$1"
    exit 1
}

printf "\n${bold}PostgreSQL %s + pgAdmin Installer${reset}\n\n" "$POSTGRES_VERSION"

# --------------------------------------------------
# Detect OS
# --------------------------------------------------

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

info "İşletim sistemi: $OS"

# --------------------------------------------------
# Check Docker
# --------------------------------------------------

if ! command -v docker >/dev/null 2>&1; then
    printf "\n"
    warn "Docker kurulu değil."

    if [ "$OS" = "macos" ]; then
        printf "\nDocker Desktop kurman gerekiyor:\n"
        printf "https://www.docker.com/products/docker-desktop/\n\n"

        if command -v brew >/dev/null 2>&1; then
            printf "Homebrew kullanıyorsan:\n\n"
            printf "  brew install --cask docker\n\n"
        fi

    else
        printf "\nDocker Engine kurman gerekiyor:\n"
        printf "https://docs.docker.com/engine/install/\n\n"
    fi

    exit 1
fi

info "Docker bulundu."

# --------------------------------------------------
# Check Docker daemon
# --------------------------------------------------

if ! docker info >/dev/null 2>&1; then
    if [ "$OS" = "macos" ]; then
        fail "Docker Desktop kurulu fakat çalışmıyor. Docker Desktop'ı açıp tekrar dene."
    else
        fail "Docker kurulu fakat daemon çalışmıyor. 'sudo systemctl start docker' deneyebilirsin."
    fi
fi

info "Docker çalışıyor."

# --------------------------------------------------
# Detect Compose
# --------------------------------------------------

if docker compose version >/dev/null 2>&1; then
    COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE="docker-compose"
else
    fail "Docker Compose bulunamadı."
fi

info "Docker Compose bulundu."

# --------------------------------------------------
# Create directory
# --------------------------------------------------

mkdir -p "$INSTALL_DIR"

info "Kurulum klasörü: $INSTALL_DIR"

# --------------------------------------------------
# compose.yml
# --------------------------------------------------

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

# --------------------------------------------------
# .env
# --------------------------------------------------

cat > "$INSTALL_DIR/.env" <<EOF
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=${POSTGRES_DB}
POSTGRES_PORT=${POSTGRES_PORT}

PGADMIN_EMAIL=${PGADMIN_EMAIL}
PGADMIN_PASSWORD=${PGADMIN_PASSWORD}
PGADMIN_PORT=${PGADMIN_PORT}
EOF

# --------------------------------------------------
# pgAdmin predefined server
# --------------------------------------------------

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

info "Yapılandırma dosyaları oluşturuldu."

# --------------------------------------------------
# Start containers
# --------------------------------------------------

cd "$INSTALL_DIR"

info "Docker image'ları indiriliyor..."

$COMPOSE -f compose.yml pull

info "PostgreSQL ve pgAdmin başlatılıyor..."

$COMPOSE -f compose.yml up -d

# --------------------------------------------------
# Wait PostgreSQL
# --------------------------------------------------

info "PostgreSQL bekleniyor..."

i=0

while [ "$i" -lt 30 ]; do

    if docker exec school-postgres \
        pg_isready \
        -U "$POSTGRES_USER" \
        -d "$POSTGRES_DB" >/dev/null 2>&1; then

        break
    fi

    i=$((i + 1))
    sleep 1
done

if [ "$i" -eq 30 ]; then
    fail "PostgreSQL zamanında hazır hale gelmedi."
fi

# --------------------------------------------------
# Finished
# --------------------------------------------------

printf "\n"
printf "${green}${bold}✓ Kurulum tamamlandı!${reset}\n\n"

printf "${bold}PostgreSQL${reset}\n"
printf "Host:     localhost\n"
printf "Port:     %s\n" "$POSTGRES_PORT"
printf "Database: %s\n" "$POSTGRES_DB"
printf "Username: %s\n" "$POSTGRES_USER"
printf "Password: %s\n" "$POSTGRES_PASSWORD"

printf "\n${bold}Bağlantı URL'si${reset}\n"
printf "postgresql://%s:%s@localhost:%s/%s\n" \
    "$POSTGRES_USER" \
    "$POSTGRES_PASSWORD" \
    "$POSTGRES_PORT" \
    "$POSTGRES_DB"

printf "\n${bold}pgAdmin${reset}\n"
printf "URL:      http://localhost:%s\n" "$PGADMIN_PORT"
printf "Email:    %s\n" "$PGADMIN_EMAIL"
printf "Password: %s\n" "$PGADMIN_PASSWORD"

printf "\n${bold}pgAdmin -> PostgreSQL${reset}\n"
printf "Host:     postgres\n"
printf "Port:     5432\n"
printf "Username: %s\n" "$POSTGRES_USER"
printf "Password: %s\n" "$POSTGRES_PASSWORD"

printf "\nDosyalar:\n"
printf "  %s\n" "$INSTALL_DIR"

printf "\nDurdurmak için:\n"
printf "  cd %s && docker compose -f compose.yml down\n" "$INSTALL_DIR"

printf "\nTamamen silmek için:\n"
printf "  cd %s && docker compose -f compose.yml down -v\n" "$INSTALL_DIR"

printf "\n"
