#!/bin/sh

# mAIcro Quick Start Script (macOS / Linux / WSL)
# Usage: curl -fsSL https://raw.githubusercontent.com/bloxez/maicroverse/main/maicro-install/run.sh | sh
#    or: curl -fsSL https://raw.githubusercontent.com/bloxez/maicroverse/main/maicro-install/run.sh | sh -s -- /path/to/data

set -e

# Configuration
IMAGE="bloxez/maicro-g2a:latest"
CONTAINER_NAME="maicro"
PORT="${MAICRO_PORT:-4321}"
HTTPS_PORT="${MAICRO_HTTPS_PORT:-443}"
DEFAULT_DATA_DIR="$HOME/maicro-data"
CONFIG_TEMPLATE_URL="${MAICRO_CONFIG_TEMPLATE_URL:-https://raw.githubusercontent.com/bloxez/maicroverse/main/maicro-install/config.platform.json}"

# Colors (using printf for POSIX compatibility)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

printf "${CYAN}"
echo "               _    ___                 "
echo "   _ __ ___   / \  |_ _| ___  _ __  ___ "
echo "  | '_ \` _ \ / _ \  | | / __|| '__|/ _ \\"
echo "  | | | | | / ___ \ | || |__ | |  | (_) |"
echo "  |_| |_| |_/_/  \_\___|\___||_|   \___/"
echo ""
printf "${NC}"
echo ""
echo "  mAIcro:G2A - Gateway to APPS"
echo ""

# Parse arguments
DATA_DIR="${1:-$DEFAULT_DATA_DIR}"
APP_DATA_DIR=""

# Check Docker is installed
if ! command -v docker > /dev/null 2>&1; then
    printf "${RED}ERROR: Docker is not installed.${NC}\n"
    echo ""
    echo "Install Docker:"
    echo "  Linux:       https://docs.docker.com/engine/install/"
    echo "  macOS/Win:   https://www.docker.com/products/docker-desktop"
    echo ""
    exit 1
fi

# Check Docker is running
if ! docker info > /dev/null 2>&1; then
    echo ""
    printf "${YELLOW}  Docker needs a little setup before we can continue.${NC}\n"
    printf "${YELLOW}  You may be asked for your password.${NC}\n"
    echo ""

    # Start Docker service if possible
    if command -v systemctl > /dev/null 2>&1; then
        printf "  Starting Docker service...\n"
        sudo systemctl start docker 2>/dev/null || true
        sleep 1
    fi

    # Add user to docker group and apply immediately
    if ! docker info > /dev/null 2>&1; then
        printf "  Setting up Docker permissions for your user...\n"
        sudo usermod -aG docker "$USER"
        # Apply group change immediately via sg and re-run this script
        printf "${GREEN}  OK: Re-running setup with new permissions...${NC}\n"
        echo ""
        sg docker -c "sh $0 $*"
        exit $?
    fi
fi

printf "${GREEN}OK: Docker is running${NC}\n"

# Resolve to absolute path
DATA_DIR=$(cd "$(dirname "$DATA_DIR")" 2>/dev/null && pwd)/$(basename "$DATA_DIR") || DATA_DIR="$DEFAULT_DATA_DIR"
APP_DATA_DIR="${DATA_DIR}/data"

# Create data directory
printf "${YELLOW}Data directory: ${DATA_DIR}${NC}\n"
mkdir -p "$DATA_DIR"
mkdir -p "$APP_DATA_DIR"
mkdir -p "${DATA_DIR}/config"

# Create platform config file from the published template (only if it doesn't already exist)
CONFIG_FILE="${DATA_DIR}/config/config.platform.json"
if [ -f "$CONFIG_FILE" ]; then
    printf "${GREEN}OK: Platform config already exists, skipping download${NC}\n"
else
    printf "${YELLOW}Downloading platform config template...${NC}\n"
    if ! curl -fsSL "$CONFIG_TEMPLATE_URL" -o "$CONFIG_FILE"; then
        printf "${RED}ERROR: Failed to download config template from:${NC} %s\n" "$CONFIG_TEMPLATE_URL"
        exit 1
    fi
fi

# Create update script
cat > "${DATA_DIR}/update.sh" << 'EOF'
#!/bin/sh
# mAIcro Update Script - Pull latest image and restart container

set -e

IMAGE="bloxez/maicro-g2a:latest"
CONTAINER_NAME="maicro"
DATA_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DATA_DIR="${DATA_DIR}/data"
CONFIG_PATH="${DATA_DIR}/config/config.platform.json"
CONFIG_TEMPLATE_URL="${MAICRO_CONFIG_TEMPLATE_URL:-https://raw.githubusercontent.com/bloxez/maicroverse/main/maicro-install/config.platform.json}"

# Parse flags
FORCE_CONFIG=0
for arg in "$@"; do
    case "$arg" in
        -f|--force) FORCE_CONFIG=1 ;;
    esac
done

echo "Checking for updates..."

# Download config template only if it doesn't exist, or -f flag is set
CONFIG_CHANGED=0
if [ "$FORCE_CONFIG" -eq 1 ]; then
    echo "Force-updating platform config template..."
    if ! curl -fsSL "$CONFIG_TEMPLATE_URL" -o "$CONFIG_PATH"; then
        echo "ERROR: Failed to download config template from ${CONFIG_TEMPLATE_URL}"
        exit 1
    fi
    CONFIG_CHANGED=1
elif [ ! -f "$CONFIG_PATH" ]; then
    echo "Downloading platform config template (first time)..."
    mkdir -p "$(dirname "$CONFIG_PATH")"
    if ! curl -fsSL "$CONFIG_TEMPLATE_URL" -o "$CONFIG_PATH"; then
        echo "ERROR: Failed to download config template from ${CONFIG_TEMPLATE_URL}"
        exit 1
    fi
    CONFIG_CHANGED=1
else
    echo "OK: Platform config exists, preserving local customisations (use -f to overwrite)"
fi

# Get current image digest
CURRENT_DIGEST=$(docker inspect --format='{{.Image}}' "$CONTAINER_NAME" 2>/dev/null || echo "")

# Pull latest
echo "Pulling latest image..."
docker pull "$IMAGE"

# Get new image digest
NEW_DIGEST=$(docker inspect --format='{{.Id}}' "$IMAGE" 2>/dev/null || echo "")

if [ "$CURRENT_DIGEST" = "$NEW_DIGEST" ]; then
        if [ "$CONFIG_CHANGED" -eq 1 ]; then
            echo "OK: Image unchanged, but config template updated. Restarting container..."
            docker stop "$CONTAINER_NAME" 2>/dev/null || true
            docker rm "$CONTAINER_NAME" 2>/dev/null || true
        else
    echo "OK: Already on latest version"
    exit 0
        fi
fi

echo "New version available, updating..."

# Stop and remove old container
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

# Get port from environment or default
PORT="${MAICRO_PORT:-4321}"
HTTPS_PORT="${MAICRO_HTTPS_PORT:-443}"

# Restart with same settings
echo "Starting updated container..."
docker run -d \
    --name "$CONTAINER_NAME" \
    -p "${PORT}:3456" \
    -p "${HTTPS_PORT}:443" \
    -v "${DATA_DIR}:/app/runtime/userdata" \
    -v "${APP_DATA_DIR}:/app/data" \
    -e "CONFIG_PATH=/app/runtime/userdata/config/config.platform.json" \
    -e "HOST_UID=$(id -u)" \
    -e "HOST_GID=$(id -g)" \
    -e "OPENROUTER_API_KEY=${OPENROUTER_API_KEY:-}" \
    -e "MAICRO_UNI_SECRET=${MAICRO_UNI_SECRET:-maicro-first-boot}" \
    -e "JWT_SECRET_INTERNAL_SIGNING_KEY=${JWT_SECRET_INTERNAL_SIGNING_KEY:-${MAICRO_UNI_SECRET:-maicro-first-boot}}" \
    -e "POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-maicro-first-boot}" \
    -e "MAICRO_ADMIN_KEY=${MAICRO_ADMIN_KEY:-maicrog2a}" \
    -e "ROOT_INSTANCE=${ROOT_INSTANCE:-root}" \
    -e "ROOT_KEY=${ROOT_KEY:-rootg2a}" \
    --add-host=host.docker.internal:host-gateway \
    --restart unless-stopped \
    "$IMAGE"

sleep 2

if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
    echo "OK: Update complete!"
    echo "mAIcro: http://localhost:${PORT}/ide"
    echo "mAIcro HTTPS: https://localhost:${HTTPS_PORT}/ide"
else
    echo "ERROR: Failed to start updated container"
    docker logs "$CONTAINER_NAME"
    exit 1
fi
EOF

chmod +x "${DATA_DIR}/update.sh"

# Create remove script
cat > "${DATA_DIR}/remove.sh" << 'EOF'
#!/bin/sh
# mAIcro Remove Script - Remove container and optionally remove persisted data

set -e

CONTAINER_NAME="maicro"
DATA_DIR="$(cd "$(dirname "$0")" && pwd)"
FORCE=0

if [ "${1:-}" = "-f" ] || [ "${1:-}" = "--force" ]; then
    FORCE=1
fi

echo "WARNING: This will remove the mAIcro container: ${CONTAINER_NAME}"
if [ "$FORCE" -eq 1 ]; then
    CONFIRM_CONTAINER="y"
else
    printf "Remove container now? [y/N]: "
    read -r CONFIRM_CONTAINER
fi

case "$CONFIRM_CONTAINER" in
    y|Y|yes|YES)
        echo "Stopping and removing container..."
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
        ;;
    *)
        echo "Cancelled."
        exit 0
        ;;
esac

echo "OK: Container removed (or was not present)."
echo ""
echo "Persisted data directory: ${DATA_DIR}"
if [ "$FORCE" -eq 1 ]; then
    CONFIRM_DATA="y"
else
    printf "Also remove persisted data from host? [y/N]: "
    read -r CONFIRM_DATA
fi

case "$CONFIRM_DATA" in
    y|Y|yes|YES)
        echo "Removing persisted data..."
        find "$DATA_DIR" -mindepth 1 -maxdepth 1 \
            ! -name "update.sh" \
            ! -name "remove.sh" \
            -exec rm -rf {} +
        echo "OK: Persisted data removed."
        ;;
    *)
        echo "Data kept at: ${DATA_DIR}"
        ;;
esac
EOF

chmod +x "${DATA_DIR}/remove.sh"

# Stop and remove existing container if it exists
if docker ps -aq -f name="$CONTAINER_NAME" | grep -q .; then
    printf "${YELLOW}Stopping existing mAIcro container...${NC}\n"
    docker stop "$CONTAINER_NAME" > /dev/null 2>&1 || true
    docker rm "$CONTAINER_NAME" > /dev/null 2>&1 || true
fi

# Pull latest image
printf "${YELLOW}Pulling mAIcro image...${NC}\n"
docker pull "$IMAGE"

# Run container
printf "${YELLOW}Starting mAIcro...${NC}\n"
docker run -d \
    --name "$CONTAINER_NAME" \
    -p "${PORT}:3456" \
    -p "${HTTPS_PORT}:443" \
    -v "${DATA_DIR}:/app/runtime/userdata" \
    -v "${APP_DATA_DIR}:/app/data" \
    -e "CONFIG_PATH=/app/runtime/userdata/config/config.platform.json" \
    -e "HOST_UID=$(id -u)" \
    -e "HOST_GID=$(id -g)" \
    -e "OPENROUTER_API_KEY=${OPENROUTER_API_KEY:-}" \
    -e "MAICRO_UNI_SECRET=${MAICRO_UNI_SECRET:-maicro-first-boot}" \
    -e "JWT_SECRET_INTERNAL_SIGNING_KEY=${JWT_SECRET_INTERNAL_SIGNING_KEY:-${MAICRO_UNI_SECRET:-maicro-first-boot}}" \
    -e "POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-maicro-first-boot}" \
    -e "MAICRO_ADMIN_KEY=${MAICRO_ADMIN_KEY:-maicrog2a}" \
    -e "ROOT_INSTANCE=${ROOT_INSTANCE:-root}" \
    -e "ROOT_KEY=${ROOT_KEY:-rootg2a}" \
    --add-host=host.docker.internal:host-gateway \
    --restart unless-stopped \
    "$IMAGE" > /dev/null

# Wait for the application to become ready
printf "${YELLOW}Waiting for mAIcro to start...${NC}\n"
READY=0
for _ in $(seq 1 180); do
    if curl -fsS "http://localhost:${PORT}/health" > /dev/null 2>&1; then
        READY=1
        break
    fi
    sleep 1
done

# Check if mAIcro is ready
if [ "$READY" -eq 1 ]; then
    echo ""
    printf "${GREEN}OK: mAIcro is running!${NC}\n"
    echo ""
    printf "  IDE:      ${CYAN}http://localhost:${PORT}/ide${NC}\n"
    printf "  GraphQL:  ${CYAN}http://localhost:${PORT}/graphql${NC}\n"
    printf "  IDE:      ${CYAN}https://localhost:${HTTPS_PORT}/ide${NC}\n"
    printf "  GraphQL:  ${CYAN}https://localhost:${HTTPS_PORT}/graphql${NC}\n"
    echo "  Data:     ${DATA_DIR}"
    echo "  DB Data:  ${APP_DATA_DIR}"
    echo ""
    echo "Commands:"
    printf "  Update:  ${YELLOW}${DATA_DIR}/update.sh${NC}\n"
    printf "  Remove:  ${YELLOW}${DATA_DIR}/remove.sh${NC}\n"
    printf "  Stop:    ${YELLOW}docker stop maicro${NC}\n"
    printf "  Start:   ${YELLOW}docker start maicro${NC}\n"
    printf "  Logs:    ${YELLOW}docker logs -f maicro${NC}\n"
    printf "  Force Remove: ${YELLOW}docker rm -f maicro${NC}\n"
    echo ""

    CREATE_MV=""
    if [ -r /dev/tty ]; then
        printf "Would you like to create a maicroverse instance now? [y/N]: " > /dev/tty
        read -r CREATE_MV < /dev/tty || CREATE_MV=""
    else
        echo "No interactive terminal detected; skipping maicroverse setup."
    fi
    case "$CREATE_MV" in
        y|Y|yes|YES)
            if ! stty -echo < /dev/tty; then
                printf "${RED}ERROR: Could not hide terminal input for OPENROUTER_API_KEY${NC}\n" > /dev/tty
                exit 1
            fi
            trap 'stty echo < /dev/tty' 0 1 2 3 15
            printf "\nEnter OPENROUTER_API_KEY (input hidden): " > /dev/tty
            read -r OPENROUTER_API_KEY < /dev/tty
            stty echo < /dev/tty
            trap - 0 1 2 3 15
            printf "\n" > /dev/tty
            docker exec -e "OPENROUTER_API_KEY=${OPENROUTER_API_KEY}" -i "$CONTAINER_NAME" bash -lc 'curl -fsSL https://raw.githubusercontent.com/bloxez/maicroverse/main/create-mv.sh -o /tmp/create-mv.sh && bash /tmp/create-mv.sh' < /dev/tty
            ;;
        *)
            echo "Skipped. You can create one later with:"
            printf "  ${YELLOW}docker exec -it maicro bash -lc 'curl -fsSL https://raw.githubusercontent.com/bloxez/maicroverse/main/create-mv.sh | bash'${NC}\n"
            ;;
    esac
else
    printf "${RED}ERROR: mAIcro did not become ready${NC}\n"
    echo "Check logs with: docker logs $CONTAINER_NAME"
    exit 1
fi
