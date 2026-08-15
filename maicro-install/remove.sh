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
