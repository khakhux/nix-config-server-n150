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

# Check if YubiKey tools are available
check_yubikey_tools() {
    if ! command -v ykman &> /dev/null; then
        return 1
    fi
    return 0
}

# Detect YubiKey and get its serial
detect_yubikey() {
    if ! check_yubikey_tools; then
        print_debug "YubiKey tools not available"
        return 1
    fi
    
    local serial=$(ykman list 2>/dev/null | grep -oP 'Serial: \K[0-9]+' | head -n1)
    
    if [ -z "$serial" ]; then
        print_debug "No YubiKey detected"
        return 1
    fi
    
    echo "$serial"
    return 0
}

# Create challenge-response authentication for LUKS
setup_yubikey_slot() {
    local container_path="$1"
    local slot="${2:-2}"  # Default to slot 2 for YubiKey challenge-response
    
    if ! check_yubikey_tools; then
        print_error "YubiKey tools not installed. Please install yubikey-manager."
        exit 1
    fi
    
    local yubikey_serial=$(detect_yubikey)
    if [ -z "$yubikey_serial" ]; then
        print_error "No YubiKey detected. Please insert your YubiKey."
        exit 1
    fi
    
    print_info "YubiKey detected (Serial: $yubikey_serial)"
    
    # Check if YubiKey challenge-response is configured
    if ! ykman oath accounts list &>/dev/null && ! ykman otp info &>/dev/null; then
        print_warn "YubiKey may not be configured for challenge-response"
        read -p "Do you want to continue anyway? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            exit 0
        fi
    fi
    
    print_info "Setting up YubiKey authentication for LUKS container..."
    print_warn "You will need to:"
    print_warn "  1. Enter the existing LUKS passphrase"
    print_warn "  2. Touch your YubiKey when prompted"
    echo ""
    
    # Use systemd-cryptenroll if available (preferred method for FIDO2)
    if command -v systemd-cryptenroll &> /dev/null; then
        print_info "Using systemd-cryptenroll (FIDO2 method)..."
        
        # Check if container is a loop device or regular file
        if [ -f "$container_path" ]; then
            print_warn "Note: systemd-cryptenroll works best with block devices."
            print_warn "For file-based containers, we'll use the alternative method."
            setup_yubikey_challenge_response "$container_path" "$slot"
        else
            systemd-cryptenroll --fido2-device=auto "$container_path"
            print_info "YubiKey FIDO2 token enrolled successfully!"
        fi
    else
        # Fall back to challenge-response method
        setup_yubikey_challenge_response "$container_path" "$slot"
    fi
}

# Alternative method: YubiKey challenge-response
setup_yubikey_challenge_response() {
    local container_path="$1"
    local slot="$2"
    
    if ! command -v ykchalresp &> /dev/null; then
        print_error "yubikey-personalization tools not installed."
        print_error "Install: yubikey-personalization (provides ykchalresp)"
        exit 1
    fi
    
    # Generate a random challenge
    local challenge=$(dd if=/dev/urandom bs=1 count=64 2>/dev/null | base64 -w 0)
    
    # Get response from YubiKey
    print_info "Touch your YubiKey..."
    local response=$(echo -n "$challenge" | ykchalresp -2 -x 2>/dev/null || echo "")
    
    if [ -z "$response" ]; then
        print_error "Failed to get response from YubiKey"
        exit 1
    fi
    
    # Store the challenge for later use
    local key_dir="$HOME/.config/luks-manager/keys"
    mkdir -p "$key_dir"
    chmod 700 "$key_dir"
    
    local key_file="$key_dir/$(basename "$container_path").challenge"
    echo -n "$challenge" > "$key_file"
    chmod 600 "$key_file"
    
    # Add the response as a new key to LUKS
    print_info "Adding YubiKey key to LUKS container (slot $slot)..."
    echo -n "$response" | cryptsetup luksAddKey "$container_path" - --key-slot "$slot"
    
    print_info "YubiKey challenge-response enrolled successfully!"
    print_info "Challenge stored in: $key_file"
    print_warn "Keep this challenge file secure - it's needed to use your YubiKey for unlocking."
}

# Mount with YubiKey authentication
mount_with_yubikey() {
    local container_path="$1"
    local mount_point="$2"
    local mapper_name="$3"
    local method="${4:-auto}"  # auto, fido2, or challenge-response
    
    print_info "Attempting to unlock with YubiKey..."
    
    local yubikey_serial=$(detect_yubikey)
    if [ -z "$yubikey_serial" ]; then
        print_error "No YubiKey detected. Please insert your YubiKey."
        return 1
    fi
    
    print_info "YubiKey detected (Serial: $yubikey_serial)"
    
    # Try FIDO2 method first if systemd-cryptenroll is available
    if [ "$method" = "auto" ] || [ "$method" = "fido2" ]; then
        if command -v systemd-cryptsetup &> /dev/null; then
            print_info "Trying FIDO2 unlock method..."
            print_info "Touch your YubiKey when it blinks..."
            
            if [ "$EUID" -ne 0 ]; then
                if sudo systemd-cryptsetup attach "$mapper_name" "$container_path" - fido2-device=auto 2>/dev/null; then
                    print_info "Unlocked with FIDO2"
                    mount_filesystem "$mapper_name" "$mount_point"
                    return 0
                fi
            else
                if systemd-cryptsetup attach "$mapper_name" "$container_path" - fido2-device=auto 2>/dev/null; then
                    print_info "Unlocked with FIDO2"
                    mount_filesystem "$mapper_name" "$mount_point"
                    return 0
                fi
            fi
            
            if [ "$method" = "fido2" ]; then
                print_error "FIDO2 unlock failed"
                return 1
            fi
            print_warn "FIDO2 unlock failed, trying challenge-response..."
        fi
    fi
    
    # Try challenge-response method
    if [ "$method" = "auto" ] || [ "$method" = "challenge-response" ]; then
        unlock_with_challenge_response "$container_path" "$mapper_name" "$mount_point"
        return $?
    fi
    
    return 1
}

# Unlock using challenge-response
unlock_with_challenge_response() {
    local container_path="$1"
    local mapper_name="$2"
    local mount_point="$3"
    
    if ! command -v ykchalresp &> /dev/null; then
        print_error "yubikey-personalization tools not installed"
        return 1
    fi
    
    local key_file="$HOME/.config/luks-manager/keys/$(basename "$container_path").challenge"
    
    if [ ! -f "$key_file" ]; then
        print_error "Challenge file not found: $key_file"
        print_error "You may need to run: luks-manager setup-yubikey $container_path"
        return 1
    fi
    
    print_info "Using challenge-response method..."
    print_info "Touch your YubiKey..."
    
    local challenge=$(cat "$key_file")
    local response=$(echo -n "$challenge" | ykchalresp -2 -x 2>/dev/null || echo "")
    
    if [ -z "$response" ]; then
        print_error "Failed to get response from YubiKey"
        return 1
    fi
    
    # Try to open with the response
    if [ "$EUID" -ne 0 ]; then
        if echo -n "$response" | sudo cryptsetup open "$container_path" "$mapper_name" --key-file=- 2>/dev/null; then
            print_info "Unlocked with YubiKey challenge-response"
            mount_filesystem "$mapper_name" "$mount_point"
            return 0
        fi
    else
        if echo -n "$response" | cryptsetup open "$container_path" "$mapper_name" --key-file=- 2>/dev/null; then
            print_info "Unlocked with YubiKey challenge-response"
            mount_filesystem "$mapper_name" "$mount_point"
            return 0
        fi
    fi
    
    print_error "Failed to unlock with YubiKey"
    return 1
}

# Helper function to mount filesystem
mount_filesystem() {
    local mapper_name="$1"
    local mount_point="$2"
    
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
        return 0
    fi
    
    print_info "Mounting filesystem..."
    if [ "$EUID" -ne 0 ]; then
        sudo mount "/dev/mapper/$mapper_name" "$mount_point"
    else
        mount "/dev/mapper/$mapper_name" "$mount_point"
    fi
    
    print_info "Mounted at $mount_point"
    df -h "$mount_point" | tail -n 1
}

# Mount a LUKS container
mount_luks() {
    local container_path="$1"
    local mount_point="$2"
    local mapper_name="$3"
    local use_yubikey="${4:-auto}"  # auto, yes, no
    
    # Validate inputs
    if [ -z "$container_path" ] || [ -z "$mount_point" ]; then
        print_error "Usage: $0 mount <container-path> <mount-point> [mapper-name] [yubikey-mode]"
        print_error "  yubikey-mode: auto (try yubikey first), yes (yubikey only), no (password only)"
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
    print_debug "YubiKey mode: $use_yubikey"
    
    # Check if already open
    if [ -e "/dev/mapper/$mapper_name" ]; then
        print_warn "Container already opened as $mapper_name"
        mount_filesystem "$mapper_name" "$mount_point"
        return 0
    fi
    
    # Try YubiKey authentication if requested
    if [ "$use_yubikey" = "auto" ] || [ "$use_yubikey" = "yes" ]; then
        if detect_yubikey >/dev/null 2>&1; then
            if mount_with_yubikey "$container_path" "$mount_point" "$mapper_name" "auto"; then
                return 0
            fi
            
            if [ "$use_yubikey" = "yes" ]; then
                print_error "YubiKey unlock failed and yubikey-only mode specified"
                exit 1
            fi
            
            print_warn "YubiKey unlock failed, falling back to password..."
        else
            if [ "$use_yubikey" = "yes" ]; then
                print_error "No YubiKey detected and yubikey-only mode specified"
                exit 1
            fi
            print_warn "No YubiKey detected, using password authentication"
        fi
    fi
    
    # Fall back to password authentication
    print_info "Opening LUKS container with password..."
    if [ "$EUID" -ne 0 ]; then
        sudo cryptsetup open "$container_path" "$mapper_name"
    else
        cryptsetup open "$container_path" "$mapper_name"
    fi
    
    print_info "Container opened as $mapper_name"
    mount_filesystem "$mapper_name" "$mount_point"
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
LUKS Manager - Manage LUKS encrypted containers with YubiKey support

USAGE:
    $0 <command> [arguments]

COMMANDS:
    mount <container-path> <mount-point> [mapper-name] [yubikey-mode]
        Mount a LUKS container
        yubikey-mode: auto (default, try YubiKey first), yes (YubiKey only), no (password only)
        
    umount <mount-point-or-mapper-name>
        Unmount and close a LUKS container
        
    list
        List all currently mounted LUKS containers
        
    status [mount-point-or-mapper-name]
        Show status of a specific container or all containers
    
    setup-yubikey <container-path> [slot]
        Enroll a YubiKey for unlocking the container
        slot: LUKS key slot to use (default: 2)
    
    help
        Show this help message

EXAMPLES:
    # Mount a container (tries YubiKey first, falls back to password)
    $0 mount /data/private.img /mnt/private
    
    # Mount with YubiKey only (no password fallback)
    $0 mount /data/private.img /mnt/private "" yes
    
    # Mount with password only (skip YubiKey)
    $0 mount /data/private.img /mnt/private "" no
    
    # Setup YubiKey authentication
    $0 setup-yubikey /data/private.img
    
    # Unmount by mount point
    $0 umount /mnt/private
    
    # List all mounted containers
    $0 list
    
    # Show status
    $0 status /mnt/private

YUBIKEY SETUP:
    Before using YubiKey authentication, you need to enroll it:
    1. Insert your YubiKey
    2. Run: $0 setup-yubikey /path/to/container.img
    3. Follow the prompts
    
    The script supports two methods:
    - FIDO2 (preferred, requires systemd-cryptenroll)
    - Challenge-Response (fallback, requires yubikey-personalization)

ENVIRONMENT VARIABLES:
    DEBUG=1     Enable debug output

DEPENDENCIES:
    Required: cryptsetup, mount, umount, findmnt
    Optional (for YubiKey): yubikey-manager, systemd (for FIDO2), 
                            yubikey-personalization (for challenge-response)

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
        setup-yubikey|setup-yk)
            setup_yubikey_slot "$@"
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