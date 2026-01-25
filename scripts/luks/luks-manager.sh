#!/usr/bin/env bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_debug() {
    if [ "${DEBUG:-0}" = "1" ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Check for required commands
check_dependencies() {
    local missing_deps=()
    
    for cmd in cryptsetup mount umount findmnt basename dirname; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required commands: ${missing_deps[*]}"
        exit 1
    fi
}

# Mount a LUKS container
mount_luks() {
    local container_path="$1"
    local mount_point="$2"
    local mapper_name="$3"
    
    # Validate inputs
    if [ -z "$container_path" ] || [ -z "$mount_point" ]; then
        print_error "Usage: $0 mount <container-path> <mount-point> [mapper-name]"
        exit 1
    fi
    
    # Check if container exists
    if [ ! -f "$container_path" ]; then
        print_error "Container not found: $container_path"
        exit 1
    fi
    
    # Generate mapper name if not provided
    if [ -z "$mapper_name" ]; then
        mapper_name=$(basename "$container_path" | sed 's/\.[^.]*$//')-encrypted
    fi
    
    print_debug "Container: $container_path"
    print_debug "Mount point: $mount_point"
    print_debug "Mapper name: $mapper_name"
    
    # Check if already open
    if [ -e "/dev/mapper/$mapper_name" ]; then
        print_warn "Container already opened as $mapper_name"
    else
        print_info "Opening LUKS container..."
        if [ "$EUID" -ne 0 ]; then
            sudo cryptsetup open "$container_path" "$mapper_name"
        else
            cryptsetup open "$container_path" "$mapper_name"
        fi
        print_info "Container opened as $mapper_name"
    fi
    
    # Create mount point if it doesn't exist
    if [ ! -d "$mount_point" ]; then
        print_info "Creating mount point: $mount_point"
        if [ "$EUID" -ne 0 ]; then
            sudo mkdir -p "$mount_point"
        else
            mkdir -p "$mount_point"
        fi
    fi
    
    # Check if already mounted
    if mountpoint -q "$mount_point" 2>/dev/null; then
        print_warn "Already mounted at $mount_point"
    else
        print_info "Mounting filesystem..."
        if [ "$EUID" -ne 0 ]; then
            sudo mount "/dev/mapper/$mapper_name" "$mount_point"
        else
            mount "/dev/mapper/$mapper_name" "$mount_point"
        fi
        print_info "Mounted at $mount_point"
    fi
    
    # Show mount info
    df -h "$mount_point" | tail -n 1
}

# Unmount a LUKS container
umount_luks() {
    local target="$1"
    
    if [ -z "$target" ]; then
        print_error "Usage: $0 umount <mount-point-or-mapper-name>"
        exit 1
    fi
    
    local mount_point=""
    local mapper_name=""
    
    # Check if target is a mount point
    if mountpoint -q "$target" 2>/dev/null; then
        mount_point="$target"
        mapper_name=$(findmnt -n -o SOURCE "$mount_point" 2>/dev/null | sed 's|/dev/mapper/||')
        print_debug "Detected mount point: $mount_point"
        print_debug "Detected mapper: $mapper_name"
    elif [ -e "/dev/mapper/$target" ]; then
        # Target is a mapper name
        mapper_name="$target"
        mount_point=$(findmnt -n -o TARGET "/dev/mapper/$mapper_name" 2>/dev/null || echo "")
        print_debug "Using mapper name: $mapper_name"
        print_debug "Found mount point: $mount_point"
    else
        print_error "Target not found: $target (not a mount point or mapper device)"
        exit 1
    fi
    
    # Unmount if mounted
    if [ -n "$mount_point" ] && mountpoint -q "$mount_point" 2>/dev/null; then
        print_info "Unmounting $mount_point..."
        if [ "$EUID" -ne 0 ]; then
            sudo umount "$mount_point"
        else
            umount "$mount_point"
        fi
        print_info "Unmounted"
    fi
    
    # Close LUKS container
    if [ -n "$mapper_name" ] && [ -e "/dev/mapper/$mapper_name" ]; then
        print_info "Closing LUKS container $mapper_name..."
        if [ "$EUID" -ne 0 ]; then
            sudo cryptsetup close "$mapper_name"
        else
            cryptsetup close "$mapper_name"
        fi
        print_info "Container closed"
    else
        print_warn "Container $mapper_name not found or already closed"
    fi
}

# List mounted LUKS containers
list_luks() {
    echo "Currently mounted LUKS containers:"
    echo "=================================="
    echo ""
    
    local found=0
    
    for mapper in /dev/mapper/*; do
        if [ -b "$mapper" ] && [ "$(basename "$mapper")" != "control" ]; then
            local mapper_name=$(basename "$mapper")
            local mount_point=$(findmnt -n -o TARGET "$mapper" 2>/dev/null || echo "not mounted")
            local size=$(lsblk -n -o SIZE "$mapper" 2>/dev/null || echo "unknown")
            
            echo "Mapper: $mapper_name"
            echo "  Device: $mapper"
            echo "  Size: $size"
            echo "  Mount point: $mount_point"
            
            if [ "$mount_point" != "not mounted" ]; then
                local usage=$(df -h "$mount_point" 2>/dev/null | tail -n 1 | awk '{print "Used: "$3" / "$2" ("$5")"}')
                echo "  $usage"
            fi
            echo ""
            found=1
        fi
    done
    
    if [ $found -eq 0 ]; then
        echo "No LUKS containers currently mounted."
    fi
}

# Get status of a specific container
status_luks() {
    local target="$1"
    
    if [ -z "$target" ]; then
        # Show all if no target specified
        list_luks
        return
    fi
    
    local mapper_name=""
    local mount_point=""
    
    # Try to interpret target
    if [ -e "/dev/mapper/$target" ]; then
        mapper_name="$target"
    elif mountpoint -q "$target" 2>/dev/null; then
        mount_point="$target"
        mapper_name=$(findmnt -n -o SOURCE "$mount_point" 2>/dev/null | sed 's|/dev/mapper/||')
    else
        print_error "Target not found: $target"
        exit 1
    fi
    
    echo "LUKS Container Status"
    echo "===================="
    echo ""
    echo "Mapper name: $mapper_name"
    
    if [ -e "/dev/mapper/$mapper_name" ]; then
        echo "Status: OPEN"
        
        local size=$(lsblk -n -o SIZE "/dev/mapper/$mapper_name" 2>/dev/null || echo "unknown")
        echo "Size: $size"
        
        mount_point=$(findmnt -n -o TARGET "/dev/mapper/$mapper_name" 2>/dev/null || echo "")
        
        if [ -n "$mount_point" ]; then
            echo "Mount point: $mount_point"
            echo ""
            df -h "$mount_point" | tail -n 1
        else
            echo "Mount point: not mounted"
        fi
    else
        echo "Status: CLOSED"
    fi
}

# Show usage
usage() {
    cat << EOF
LUKS Manager - Manage LUKS encrypted containers

USAGE:
    $0 <command> [arguments]

COMMANDS:
    mount <container-path> <mount-point> [mapper-name]
        Mount a LUKS container
        
    umount <mount-point-or-mapper-name>
        Unmount and close a LUKS container
        
    list
        List all currently mounted LUKS containers
        
    status [mount-point-or-mapper-name]
        Show status of a specific container or all containers
        
    help
        Show this help message

EXAMPLES:
    # Mount a container
    $0 mount /data/private.img /mnt/private
    
    # Mount with custom mapper name
    $0 mount /data/backup.img /mnt/backup my-backup
    
    # Unmount by mount point
    $0 umount /mnt/private
    
    # Unmount by mapper name
    $0 umount private-encrypted
    
    # List all mounted containers
    $0 list
    
    # Show status
    $0 status /mnt/private

ENVIRONMENT VARIABLES:
    DEBUG=1     Enable debug output

EOF
    exit 0
}

# Main script logic
main() {
    check_dependencies
    
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        mount)
            mount_luks "$@"
            ;;
        umount|unmount)
            umount_luks "$@"
            ;;
        list|ls)
            list_luks
            ;;
        status)
            status_luks "$@"
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            usage
            ;;
    esac
}

main "$@"