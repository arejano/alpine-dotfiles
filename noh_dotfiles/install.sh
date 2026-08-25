#!/bin/bash

# Install script for noh_dotfiles
# This script installs the development environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print with color
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_error "Please do not run this script as root"
        exit 1
    fi
}

# Detect package manager
detect_package_manager() {
    if command -v pacman &> /dev/null; then
        echo "pacman"
    elif command -v apt &> /dev/null; then
        echo "apt"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v brew &> /dev/null; then
        echo "brew"
    else
        echo "unknown"
    fi
}

# Install packages based on package manager
install_packages() {
    local pkg_manager=$(detect_package_manager)
    
    case $pkg_manager in
        pacman)
            print_status "Installing packages with pacman..."
            sudo pacman -S --needed --noconfirm \
                helix \
                zellij \
                sway \
                foot \
                wmenu \
                waybar \
                grim \
                slurp \
                wl-clipboard \
                xdg-desktop-portal-wlr
            ;;
        apt)
            print_status "Installing packages with apt..."
            sudo apt update
            sudo apt install -y \
                helix \
                zellij \
                sway \
                foot \
                bemenu \
                waybar \
                grim \
                slurp \
                wl-clipboard
            ;;
        dnf)
            print_status "Installing packages with dnf..."
            sudo dnf install -y \
                helix \
                zellij \
                sway \
                foot \
                wmenu \
                waybar \
                grim \
                slurp \
                wl-clipboard
            ;;
        brew)
            print_status "Installing packages with brew..."
            brew install \
                helix \
                zellij \
                sway \
                foot \
                wmenu \
                waybar \
                grim \
                slurp \
                wl-clipboard
            ;;
        *)
            print_error "Unknown package manager. Please install packages manually."
            exit 1
            ;;
    esac
}

# Install language servers
install_language_servers() {
    local pkg_manager=$(detect_package_manager)
    
    print_status "Installing language servers..."
    
    case $pkg_manager in
        pacman)
            sudo pacman -S --needed --noconfirm \
                zls \
                typescript-language-server \
                nodejs \
                npm
            ;;
        apt)
            sudo apt install -y \
                zls \
                nodejs \
                npm
            sudo npm install -g typescript-language-server
            ;;
        dnf)
            sudo dnf install -y \
                zls \
                nodejs \
                npm
            sudo npm install -g typescript-language-server
            ;;
        brew)
            brew install \
                zls \
                node \
                typescript-language-server
            ;;
        *)
            print_warning "Could not install language servers automatically"
            ;;
    esac
}

# Create necessary directories
create_directories() {
    print_status "Creating directories..."
    
    mkdir -p ~/.config/sway
    mkdir -p ~/.config/helix
    mkdir -p ~/.config/zellij
    mkdir -p ~/bin
}

# Copy configuration files
copy_configs() {
    print_status "Copying configuration files..."
    
    # Copy sway config
    if [ -f .config/sway/config ]; then
        cp .config/sway/config ~/.config/sway/config
        print_status "Sway config copied"
    fi
    
    # Copy helix config
    if [ -f .config/helix/config.toml ]; then
        cp .config/helix/config.toml ~/.config/helix/config.toml
        print_status "Helix config copied"
    fi
    
    # Copy zellij config
    if [ -f .config/zellij/config.kdl ]; then
        cp .config/zellij/config.kdl ~/.config/zellij/config.kdl
        print_status "Zellij config copied"
    fi
    
    # Copy dev script
    if [ -f bin/dev ]; then
        cp bin/dev ~/bin/dev
        chmod +x ~/bin/dev
        print_status "Dev script copied"
    fi
    
    # Copy bashrc additions
    if [ -f .bashrc ]; then
        if ! grep -q "noh_dotfiles" ~/.bashrc 2>/dev/null; then
            echo "" >> ~/.bashrc
            echo "# noh_dotfiles configuration" >> ~/.bashrc
            echo "source ~/git/noh_dotfiles/.bashrc" >> ~/.bashrc
            print_status "Bashrc updated"
        else
            print_warning "Bashrc already configured"
        fi
    fi
}

# Setup git repositories
setup_git() {
    print_status "Setting up git repositories..."
    
    # Initialize dotfiles repo if not already initialized
    if [ ! -d ~/git/dotfiles/.git ]; then
        mkdir -p ~/git
        cd ~/git
        git clone https://github.com/another-user/dotfiles.git
        cd -
        print_status "Dotfiles repository cloned"
    fi
    
    # Initialize noh_dotfiles repo if not already initialized
    if [ ! -d ~/git/noh_dotfiles/.git ]; then
        cd ~/git/noh_dotfiles
        git init
        git add .
        git commit -m "Initial commit"
        print_status "Noh dotfiles repository initialized"
        cd -
    fi
}

# Main installation function
main() {
    echo "=================================="
    echo "   noh_dotfiles Environment Setup"
    echo "=================================="
    echo ""
    
    # Check if running as root
    check_root
    
    # Install packages
    install_packages
    
    # Install language servers
    install_language_servers
    
    # Create directories
    create_directories
    
    # Copy configuration files
    copy_configs
    
    # Setup git repositories
    setup_git
    
    echo ""
    echo "=================================="
    print_status "Installation complete!"
    echo "=================================="
    echo ""
    echo "To start using the environment:"
    echo "1. Log out and log back in (or source ~/.bashrc)"
    echo "2. Run 'dev' to start development environment"
    echo "3. Use 'hx' as alias for helix"
    echo ""
    echo "Key bindings:"
    echo "- Win+Space: Open menu"
    echo "- Win+Return: Open terminal"
    echo "- Win+q: Kill window"
    echo "- Win+h/j/k/l: Navigate windows"
    echo ""
}

# Run main function
main
