#!/usr/bin/env bash

set -e  # Exit on error

# Default values
DEFAULT_SIZE="10G"
DEFAULT_FS="ext4"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Function to show usage
usage() {
    cat << EOF
Usage: $0 -p PATH [-s SIZE] [-f FILESYSTEM] [-n NAME]

Create a LUKS encrypted container.

OPTIONS:
    -p PATH         Path to the container image file (required)
    -s SIZE         Size of the container (default: ${DEFAULT_SIZE})
                    Examples: 10G, 500M, 1T
    -f FILESYSTEM   Filesystem type (default: ${DEFAULT_FS})
                    Options: ext4, xfs, btrfs
    -n NAME         Mapper name (default: derived from filename)
    -h              Show this help message

EXAMPLES:
    $0 -p /data/encrypted.img -s 20G
    $0 -p /home/user/private.img -s 500M -f xfs
    $0 -p /mnt/secure.img -s 1T -n my-secure-storage

EOF
    exit 1
}

# Function to convert size to MB for dd
size_to_mb() {
    local size=$1
    local number=${size//[^0-9]/}
    local unit=${size//[0-9]/}
    
    case ${unit^^} in
        G|GB)
            echo $((number * 1024))
            ;;
        M|MB)
            echo $number
            ;;
        T|TB)
            echo $((number * 1024 * 1024))
            ;;
        K|KB)
            echo $((number / 1024))
            ;;
        *)
            print_error "Unknown size unit: $unit (use M, G, or T)"
            exit 1
            ;;
    esac
}

# Parse command line arguments
CONTAINER_PATH=""
SIZE="$DEFAULT_SIZE"
FILESYSTEM="$DEFAULT_FS"
MAPPER_NAME=""

while getopts "p:s:f:n:h" opt; do
    case $opt in
        p)
            CONTAINER_PATH="$OPTARG"
            ;;
        s)
            SIZE="$OPTARG"
            ;;
        f)
            FILESYSTEM="$OPTARG"
            ;;
        n)
            MAPPER_NAME="$OPTARG"
            ;;
        h)
            usage
            ;;
        \?)
            print_error "Invalid option: -$OPTARG"
            usage
            ;;
    esac
done

# Check if required parameters are provided
if [ -z "$CONTAINER_PATH" ]; then
    print_error "Container path is required"
    usage
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

# Derive mapper name from filename if not provided
if [ -z "$MAPPER_NAME" ]; then
    MAPPER_NAME=$(basename "$CONTAINER_PATH" | sed 's/\.[^.]*$//')
    MAPPER_NAME="${MAPPER_NAME}-encrypted"
fi

# Check if file already exists
if [ -f "$CONTAINER_PATH" ]; then
    print_warn "File $CONTAINER_PATH already exists!"
    read -p "Do you want to overwrite it? This will DELETE all data! (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        print_info "Aborted."
        exit 0
    fi
fi

# Create directory if it doesn't exist
CONTAINER_DIR=$(dirname "$CONTAINER_PATH")
if [ ! -d "$CONTAINER_DIR" ]; then
    print_info "Creating directory: $CONTAINER_DIR"
    mkdir -p "$CONTAINER_DIR"
fi

# Convert size to MB
SIZE_MB=$(size_to_mb "$SIZE")

print_info "Creating LUKS container with the following parameters:"
echo "  Path:       $CONTAINER_PATH"
echo "  Size:       $SIZE ($SIZE_MB MB)"
echo "  Filesystem: $FILESYSTEM"
echo "  Mapper:     $MAPPER_NAME"
echo ""

# Create the container file
print_info "Creating container file (this may take a while)..."
dd if=/dev/zero of="$CONTAINER_PATH" bs=1M count="$SIZE_MB" status=progress

# Format as LUKS
print_info "Formatting as LUKS container..."
print_warn "You will be asked to enter a passphrase for encryption."
cryptsetup luksFormat "$CONTAINER_PATH"

# Open the LUKS container
print_info "Opening LUKS container..."
cryptsetup open "$CONTAINER_PATH" "$MAPPER_NAME"

# Create filesystem
print_info "Creating $FILESYSTEM filesystem..."
case $FILESYSTEM in
    ext4)
        mkfs.ext4 -L "encrypted" "/dev/mapper/$MAPPER_NAME"
        ;;
    xfs)
        mkfs.xfs -L "encrypted" "/dev/mapper/$MAPPER_NAME"
        ;;
    btrfs)
        mkfs.btrfs -L "encrypted" "/dev/mapper/$MAPPER_NAME"
        ;;
    *)
        print_error "Unsupported filesystem: $FILESYSTEM"
        cryptsetup close "$MAPPER_NAME"
        exit 1
        ;;
esac

# Close the container
print_info "Closing LUKS container..."
cryptsetup close "$MAPPER_NAME"

print_info "LUKS container created successfully!"
echo ""
print_info "To use this container:"
echo "  Open:  cryptsetup open $CONTAINER_PATH $MAPPER_NAME"
echo "  Mount: mount /dev/mapper/$MAPPER_NAME /mnt/point"
echo "  Umount: umount /mnt/point"
echo "  Close: cryptsetup close $MAPPER_NAME"
echo ""