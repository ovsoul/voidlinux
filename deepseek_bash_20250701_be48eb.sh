#!/bin/bash

# Script de post-instalación completo para Void Linux - KDE Plasma
# Versión: 4.1 - Completa y verificada para APU Kaveri
# Incluye todas las correcciones: paquetes, pantalla negra, red y audio
# Autor: Asistente Void Linux - Última actualización: Octubre 2023

set -euo pipefail
trap 'handle_error $? $LINENO' ERR

## Configuración básica
VERSION="4.1"
LOG_FILE="/var/log/void_kde_install_$(date +%Y%m%d_%H%M%S).log"
USERNAME=$(whoami)
REBOOT_NEEDED=false

## Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

## --- Funciones principales ---

## Manejo de errores mejorado
handle_error() {
    local exit_code=$1
    local line_no=$2
    echo -e "${RED}[ERROR]${NC} Error en línea $line_no - Código $exit_code" | tee -a "$LOG_FILE"
    echo -e "${YELLOW}[INFO]${NC} Consulta el log completo: $LOG_FILE" | tee -a "$LOG_FILE"
    
    # Restaurar configuraciones críticas
    [ -f /etc/sddm.conf.d/00-x11.conf.bak ] && sudo mv /etc/sddm.conf.d/00-x11.conf.bak /etc/sddm.conf.d/00-x11.conf
    [ -f /etc/X11/xorg.conf.d/10-radeon.conf.bak ] && sudo mv /etc/X11/xorg.conf.d/10-radeon.conf.bak /etc/X11/xorg.conf.d/10-radeon.conf
    [ -f /etc/default/grub.bak ] && sudo mv /etc/default/grub.bak /etc/default/grub
    
    exit $exit_code
}

## Funciones de logging mejoradas
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    case "$level" in
        "INFO") color="${BLUE}" ;;
        "SUCCESS") color="${GREEN}" ;;
        "WARNING") color="${YELLOW}" ;;
        "ERROR") color="${RED}" ;;
        "STEP") color="${CYAN}" ;;
        *) color="${NC}" ;;
    esac
    
    echo -e "${color}[${level}]${NC} ${timestamp} - ${message}" | tee -a "$LOG_FILE"
}

## Verificación de paquetes
verify_pkg() {
    if ! xbps-query -R "$1" &>/dev/null; then
        log "WARNING" "Paquete $1 no encontrado en repositorios"
        return 1
    fi
    return 0
}

## Verificación de conexión
check_internet() {
    log "STEP" "Verificando conexión a Internet..."
    if ! ping -c 1 -W 5 google.com >/dev/null 2>&1 && ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        log "ERROR" "No hay conexión a Internet"
        exit 1
    fi
    log "SUCCESS" "Conexión a Internet verificada"
}

## Actualización del sistema
update_system() {
    log "STEP" "Actualizando sistema base..."
    sudo xbps-install -Suy 2>&1 | tee -a "$LOG_FILE"
    log "SUCCESS" "Sistema actualizado"
}

## Configuración de repositorios
setup_repos() {
    log "STEP" "Configurando repositorios adicionales..."
    
    local repos=(
        "void-repo-nonfree"
        "void-repo-multilib"
        "void-repo-multilib-nonfree"
    )
    
    for repo in "${repos[@]}"; do
        if verify_pkg "$repo"; then
            sudo xbps-install -y "$repo" 2>&1 | tee -a "$LOG_FILE"
            log "INFO" "Repositorio $repo añadido"
        fi
    done
    
    sudo xbps-install -S 2>&1 | tee -a "$LOG_FILE"
    log "SUCCESS" "Repositorios configurados"
}

## Instalación de controladores AMD (Kaveri)
install_amd_drivers() {
    log "STEP" "Instalando controladores AMD para Kaveri..."
    
    local amd_packages=(
        "mesa-dri"
        "xf86-video-ati"
        "linux-firmware-amd"
        "mesa-vaapi"
        "mesa-vdpau"
        "libva-mesa-driver"
    )
    
    for pkg in "${amd_packages[@]}"; do
        if verify_pkg "$pkg"; then
            sudo xbps-install -y "$pkg" 2>&1 | tee -a "$LOG_FILE"
        fi
    done
    
    log "SUCCESS" "Controladores AMD instalados"
}

## Configuración específica para Kaveri
configure_kaveri() {
    log "STEP" "Aplicando configuraciones específicas para APU Kaveri..."
    
    # 1. Configuración Xorg para radeon
    sudo mkdir -p /etc/X11/xorg.conf.d
    [ -f /etc/X11/xorg.conf.d/10-radeon.conf ] && sudo cp /etc/X11/xorg.conf.d/10-radeon.conf /etc/X11/xorg.conf.d/10-radeon.conf.bak
    
    cat << 'EOF' | sudo tee /etc/X11/xorg.conf.d/10-radeon.conf
Section "Device"
    Identifier "Radeon"
    Driver "radeon"
    Option "AccelMethod" "glamor"
    Option "DRI" "3"
    Option "TearFree" "on"
EndSection
EOF

    # 2. Parámetros del kernel
    sudo cp /etc/default/grub /etc/default/grub.bak
    sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/&radeon.si_support=1 radeon.cik_support=1 radeon.modeset=1 /' /etc/default/grub
    sudo update-grub

    # 3. Configuración KWin
    mkdir -p ~/.config
    cat > ~/.config/kwinrc << 'EOF'
[Compositing]
Backend=xrender
Enabled=true
GLPlatformInterface=glx
EOF

    log "SUCCESS" "Configuraciones Kaveri aplicadas"
}

## Instalación de KDE Plasma
install_kde_plasma() {
    log "STEP" "Instalando KDE Plasma..."
    
    local kde_packages=(
        "plasma-desktop"
        "plasma-workspace"
        "kwin"
        "sddm"
        "sddm-kcm"
        "plasma-nm"
        "plasma-pa"
        "kde-cli-tools"
        "dolphin"
        "konsole"
        "kate"
        "breeze"
        "breeze-gtk"
        "breeze-icons"
    )
    
    for pkg in "${kde_packages[@]}"; do
        if verify_pkg "$pkg"; then
            sudo xbps-install -y "$pkg" 2>&1 | tee -a "$LOG_FILE"
        fi
    done
    
    log "SUCCESS" "KDE Plasma instalado"
}

## Configuración de SDDM
configure_sddm() {
    log "STEP" "Configurando SDDM..."
    
    sudo mkdir -p /etc/sddm.conf.d
    [ -f /etc/sddm.conf.d/00-x11.conf ] && sudo cp /etc/sddm.conf.d/00-x11.conf /etc/sddm.conf.d/00-x11.conf.bak
    
    cat << 'EOF' | sudo tee /etc/sddm.conf.d/00-x11.conf
[Autologin]
Session=plasma.desktop

[X11]
ServerPath=/usr/bin/X
DisplayCommand=/usr/share/sddm/scripts/Xsetup
EOF

    log "SUCCESS" "SDDM configurado"
}

## Configuración de red para suspensión
configure_network_resume() {
    log "STEP" "Configurando red para resistir suspensión..."
    
    sudo mkdir -p /etc/NetworkManager/conf.d
    cat << 'EOF' | sudo tee /etc/NetworkManager/conf.d/suspend-resume.conf
[connection]
wifi.powersave=2
connection.auto-reconnect=true

[device]
wifi.scan-rand-mac-address=no
EOF

    mkdir -p ~/.config/autostart
    cat > ~/.config/autostart/network-resume.desktop << 'EOF'
[Desktop Entry]
Name=Reparar red tras suspensión
Exec=sh -c "nmcli networking off && sleep 2 && nmcli networking on"
Type=Application
Terminal=false
EOF

    log "SUCCESS" "Configuración de red para suspensión completada"
}

## Instalación y configuración de PipeWire
install_pipewire() {
    log "STEP" "Instalando PipeWire para audio..."
    
    local audio_packages=(
        "pipewire"
        "wireplumber"
        "pipewire-pulse"
        "pipewire-alsa"
        "libspa-bluetooth"
        "pavucontrol"
        "alsa-utils"
    )
    
    for pkg in "${audio_packages[@]}"; do
        if verify_pkg "$pkg"; then
            sudo xbps-install -y "$pkg" 2>&1 | tee -a "$LOG_FILE"
        fi
    done

    # Configurar el entorno para el usuario
    mkdir -p ~/.config/pipewire
    cp /usr/share/pipewire/pipewire.conf ~/.config/pipewire/
    
    # Configurar sesión de usuario
    echo "export PIPEWIRE_RUNTIME_DIR=/run/user/\$(id -u)" >> ~/.bashrc
    
    log "SUCCESS" "PipeWire instalado y configurado"
}

## Habilitación de servicios
enable_services() {
    log "STEP" "Habilitando servicios esenciales..."
    
    local services=(
        "dbus"
        "NetworkManager"
        "elogind"
        "polkitd"
        "acpid"
        "rtkit"
        "sddm"
    )
    
    for svc in "${services[@]}"; do
        if [ -d "/etc/sv/$svc" ]; then
            sudo ln -sf "/etc/sv/$svc" "/var/service/"
            log "INFO" "Servicio $svc habilitado"
        else
            log "WARNING" "Servicio $svc no encontrado"
        fi
    done
    
    log "SUCCESS" "Servicios habilitados"
}

## Instalación de aplicaciones adicionales
install_apps() {
    log "STEP" "Instalando aplicaciones recomendadas..."
    
    local apps=(
        "firefox"
        "vlc"
        "libreoffice"
        "neofetch"
        "htop"
        "git"
        "gparted"
        "flatpak"
    )
    
    for app in "${apps[@]}"; do
        if verify_pkg "$app"; then
            sudo xbps-install -y "$app" 2>&1 | tee -a "$LOG_FILE"
        fi
    done
    
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    log "SUCCESS" "Aplicaciones instaladas"
}

## Creación de script de diagnóstico
create_diagnostic() {
    log "STEP" "Creando script de diagnóstico..."
    
    cat > ~/void-kde-diag.sh << 'EOF'
#!/bin/bash
echo "=== DIAGNÓSTICO VOID KDE ==="
echo "Fecha: $(date)"
echo "============================"

echo -e "\n[1] Sistema:"
uname -a
cat /etc/os-release

echo -e "\n[2] Gráficos:"
lspci -nn | grep -i "vga\|amd"
glxinfo | grep -i "renderer\|version" || echo "glxinfo no disponible"

echo -e "\n[3] Red:"
nmcli device status
ip a

echo -e "\n[4] Servicios:"
sv status /var/service/*

echo -e "\n[5] Xorg:"
cat /var/log/Xorg.0.log | grep -i "EE\|WW" | tail -20

echo -e "\n[6] KDE:"
qdbus org.kde.KWin /KWin supportInformation | head -20

echo -e "\n[7] Audio:"
pipewire --version
pactl info

echo -e "\n=== FIN DIAGNÓSTICO ==="
EOF

    chmod +x ~/void-kde-diag.sh
    log "SUCCESS" "Script de diagnóstico creado"
}

## Función principal
main() {
    clear
    echo -e "${GREEN}"
    echo "  ██████╗  ██████╗ ██╗██████╗     ██╗  ██╗██████╗ ███████╗"
    echo "  ██╔══██╗██╔═══██╗██║██╔══██╗    ██║ ██╔╝██╔══██╗██╔════╝"
    echo "  ██████╔╝██║   ██║██║██║  ██║    █████╔╝ ██║  ██║█████╗  "
    echo "  ██╔══██╗██║   ██║██║██║  ██║    ██╔═██╗ ██║  ██║██╔══╝  "
    echo "  ██║  ██║╚██████╔╝██║██████╔╝    ██║  ██╗██████╔╝███████╗"
    echo "  ╚═╝  ╚═╝ ╚═════╝ ╚═╝╚═════╝     ╚═╝  ╚═╝╚═════╝ ╚══════╝"
    echo -e "${NC}"
    
    log "STEP" "Iniciando instalación de Void Linux con KDE Plasma"
    
    check_internet
    update_system
    setup_repos
    install_amd_drivers
    configure_kaveri
    install_kde_plasma
    configure_sddm
    install_pipewire
    configure_network_resume
    enable_services
    install_apps
    create_diagnostic
    
    REBOOT_NEEDED=true
    
    echo -e "${GREEN}"
    echo "Instalación completada exitosamente!"
    echo -e "${NC}"
    echo "Próximos pasos:"
    echo "1. Reinicia el sistema: sudo reboot"
    echo "2. Para diagnóstico ejecuta: ~/void-kde-diag.sh"
    echo ""
    echo "Log completo de la instalación: $LOG_FILE"
    
    if $REBOOT_NEEDED; then
        echo -e "${YELLOW}"
        read -p "¿Deseas reiniciar ahora? [s/N]: " choice
        echo -e "${NC}"
        if [[ "$choice" =~ ^[SsYy]$ ]]; then
            sudo reboot
        fi
    fi
}

main "$@"