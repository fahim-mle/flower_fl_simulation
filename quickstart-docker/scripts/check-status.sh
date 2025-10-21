#!/bin/bash

# Flower FL Docker Deployment Status Monitoring Script
# This script checks the health and status of all Flower FL containers

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Change to script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# Parse command line arguments
SHOW_LOGS=false
FOLLOW_LOGS=false
SERVICE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --logs|-l)
            SHOW_LOGS=true
            shift
            ;;
        --follow|-f)
            SHOW_LOGS=true
            FOLLOW_LOGS=true
            shift
            ;;
        --service|-s)
            SERVICE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -l, --logs           Show recent logs from all services"
            echo "  -f, --follow         Follow logs in real-time"
            echo "  -s, --service NAME   Show status/logs for specific service"
            echo "                       (superlink, superexec, supernode-1, supernode-2)"
            echo "  -h, --help           Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                    # Show status of all services"
            echo "  $0 --logs             # Show recent logs"
            echo "  $0 --follow           # Follow logs in real-time"
            echo "  $0 -s superlink -l    # Show SuperLink logs"
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

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Flower FL Deployment Status${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running${NC}"
    exit 1
fi

# Check if containers exist
if ! docker compose ps -q 2>/dev/null | grep -q .; then
    echo -e "${YELLOW}No Flower FL containers are running.${NC}"
    echo -e "${BLUE}Start the deployment with: ${YELLOW}./scripts/start-secure.sh${NC}"
    echo ""
    exit 0
fi

# Function to get container status
get_container_status() {
    local container_name=$1
    local status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "not found")
    local health=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "none")

    if [ "$status" = "running" ]; then
        if [ "$health" = "healthy" ]; then
            echo -e "${GREEN}✓ Running (Healthy)${NC}"
        elif [ "$health" = "unhealthy" ]; then
            echo -e "${RED}✗ Running (Unhealthy)${NC}"
        elif [ "$health" = "starting" ]; then
            echo -e "${YELLOW}○ Running (Starting)${NC}"
        else
            echo -e "${GREEN}✓ Running${NC}"
        fi
    elif [ "$status" = "exited" ]; then
        echo -e "${RED}✗ Stopped${NC}"
    elif [ "$status" = "restarting" ]; then
        echo -e "${YELLOW}↻ Restarting${NC}"
    else
        echo -e "${RED}✗ $status${NC}"
    fi
}

# Function to show container info
show_container_info() {
    local service_name=$1
    local container_name=$2

    echo -e "${CYAN}$service_name:${NC}"
    echo -e "  Container: $container_name"
    echo -e "  Status:    $(get_container_status $container_name)"

    if docker ps -q -f name="$container_name" 2>/dev/null | grep -q .; then
        local uptime=$(docker inspect --format='{{.State.StartedAt}}' "$container_name" 2>/dev/null | xargs -I {} date -d {} +"%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "unknown")
        local cpu=$(docker stats --no-stream --format "{{.CPUPerc}}" "$container_name" 2>/dev/null || echo "N/A")
        local mem=$(docker stats --no-stream --format "{{.MemUsage}}" "$container_name" 2>/dev/null || echo "N/A")

        echo -e "  Started:   $uptime"
        echo -e "  CPU:       $cpu"
        echo -e "  Memory:    $mem"

        # Show port mappings if any
        local ports=$(docker port "$container_name" 2>/dev/null || echo "")
        if [ -n "$ports" ]; then
            echo -e "  Ports:     $ports"
        fi
    fi
    echo ""
}

# Show status for all services or specific service
if [ -n "$SERVICE" ]; then
    case $SERVICE in
        superlink)
            show_container_info "SuperLink" "flower-superlink"
            ;;
        superexec)
            show_container_info "SuperExec" "flower-superexec"
            ;;
        supernode-1)
            show_container_info "SuperNode 1" "flower-supernode-1"
            ;;
        supernode-2)
            show_container_info "SuperNode 2" "flower-supernode-2"
            ;;
        *)
            echo -e "${RED}Unknown service: $SERVICE${NC}"
            echo "Valid services: superlink, superexec, supernode-1, supernode-2"
            exit 1
            ;;
    esac
else
    show_container_info "SuperLink" "flower-superlink"
    show_container_info "SuperExec" "flower-superexec"
    show_container_info "SuperNode 1" "flower-supernode-1"
    show_container_info "SuperNode 2" "flower-supernode-2"
fi

# Show network information
echo -e "${CYAN}Network:${NC}"
if docker network ls | grep -q "flower-fl-network"; then
    echo -e "  Name:      flower-fl-network"
    echo -e "  Status:    ${GREEN}Active${NC}"
    echo -e "  Driver:    bridge"
else
    echo -e "  Status:    ${RED}Not found${NC}"
fi
echo ""

# Show volume information
echo -e "${CYAN}Volumes:${NC}"
docker volume ls | grep "flower-" | awk '{print "  • " $2}' || echo -e "  ${YELLOW}No volumes found${NC}"
echo ""

# Show logs if requested
if [ "$SHOW_LOGS" = true ]; then
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Container Logs${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    if [ "$FOLLOW_LOGS" = true ]; then
        if [ -n "$SERVICE" ]; then
            echo -e "${YELLOW}Following logs for $SERVICE (Ctrl+C to stop)...${NC}"
            docker compose logs -f "$SERVICE"
        else
            echo -e "${YELLOW}Following logs for all services (Ctrl+C to stop)...${NC}"
            docker compose logs -f
        fi
    else
        if [ -n "$SERVICE" ]; then
            docker compose logs --tail=50 "$SERVICE"
        else
            docker compose logs --tail=20
        fi
    fi
fi

# Show helpful commands if not showing logs
if [ "$SHOW_LOGS" = false ]; then
    echo -e "${BLUE}Useful commands:${NC}"
    echo -e "  • View all logs:          ${YELLOW}./scripts/check-status.sh --logs${NC}"
    echo -e "  • Follow logs:            ${YELLOW}./scripts/check-status.sh --follow${NC}"
    echo -e "  • Check specific service: ${YELLOW}./scripts/check-status.sh -s superlink${NC}"
    echo -e "  • Stop deployment:        ${YELLOW}./scripts/stop-secure.sh${NC}"
    echo ""
fi
