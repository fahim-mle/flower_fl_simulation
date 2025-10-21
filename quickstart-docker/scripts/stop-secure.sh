#!/bin/bash

# Secure Flower FL Docker Deployment Shutdown Script
# This script stops and cleans up the Flower FL infrastructure

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Flower FL Deployment Shutdown${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Change to script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# Parse command line arguments
REMOVE_VOLUMES=false
REMOVE_IMAGES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --volumes|-v)
            REMOVE_VOLUMES=true
            shift
            ;;
        --images|-i)
            REMOVE_IMAGES=true
            shift
            ;;
        --all|-a)
            REMOVE_VOLUMES=true
            REMOVE_IMAGES=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -v, --volumes    Remove persistent volumes (model data, logs, cache)"
            echo "  -i, --images     Remove Docker images"
            echo "  -a, --all        Remove everything (volumes + images)"
            echo "  -h, --help       Show this help message"
            echo ""
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo -e "${YELLOW}[1/3] Stopping Flower FL containers...${NC}"

# Stop containers
if docker compose ps -q 2>/dev/null | grep -q .; then
    docker compose down
    echo -e "${GREEN}  ✓ Containers stopped${NC}"
else
    echo -e "${YELLOW}  ℹ No running containers found${NC}"
fi

echo ""
echo -e "${YELLOW}[2/3] Cleaning up resources...${NC}"

if [ "$REMOVE_VOLUMES" = true ]; then
    echo -e "${YELLOW}  Removing persistent volumes...${NC}"

    # List volumes to be removed
    docker volume ls | grep -E "flower-(superlink|supernode|model)" | awk '{print $2}' | while read volume; do
        echo -e "    • Removing volume: $volume"
        docker volume rm "$volume" 2>/dev/null || echo -e "${YELLOW}      Volume already removed or in use${NC}"
    done

    echo -e "${GREEN}  ✓ Volumes removed${NC}"
else
    echo -e "${BLUE}  ℹ Persistent volumes preserved (use --volumes to remove)${NC}"
fi

echo ""

if [ "$REMOVE_IMAGES" = true ]; then
    echo -e "${YELLOW}  Removing Docker images...${NC}"

    # Remove custom-built images
    docker images | grep -E "quickstart-docker.*superlink|quickstart-docker.*supernode|quickstart-docker.*superexec" | awk '{print $3}' | while read image_id; do
        echo -e "    • Removing image: $image_id"
        docker rmi "$image_id" 2>/dev/null || echo -e "${YELLOW}      Image already removed or in use${NC}"
    done

    echo -e "${GREEN}  ✓ Images removed${NC}"
else
    echo -e "${BLUE}  ℹ Docker images preserved (use --images to remove)${NC}"
fi

echo ""
echo -e "${YELLOW}[3/3] Cleaning up network...${NC}"

# Remove network if it exists and is not in use
if docker network ls | grep -q "flower-fl-network"; then
    docker network rm flower-fl-network 2>/dev/null && echo -e "${GREEN}  ✓ Network removed${NC}" || echo -e "${YELLOW}  ℹ Network in use or already removed${NC}"
else
    echo -e "${YELLOW}  ℹ Network not found${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Shutdown Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Show summary
echo -e "${BLUE}Summary:${NC}"
echo -e "  • Containers:  ${GREEN}Stopped${NC}"
echo -e "  • Volumes:     $([ "$REMOVE_VOLUMES" = true ] && echo -e "${GREEN}Removed${NC}" || echo -e "${YELLOW}Preserved${NC}")"
echo -e "  • Images:      $([ "$REMOVE_IMAGES" = true ] && echo -e "${GREEN}Removed${NC}" || echo -e "${YELLOW}Preserved${NC}")"
echo ""

if [ "$REMOVE_VOLUMES" = false ] || [ "$REMOVE_IMAGES" = false ]; then
    echo -e "${BLUE}Tip: To remove all resources, use:${NC}"
    echo -e "${YELLOW}  ./scripts/stop-secure.sh --all${NC}"
    echo ""
fi

echo -e "${BLUE}To start the deployment again:${NC}"
echo -e "${YELLOW}  ./scripts/start-secure.sh${NC}"
echo ""
