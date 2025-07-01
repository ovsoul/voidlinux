#!/bin/bash

# Script de post-instalación optimizado para Void Linux - KDE Plasma
# Versión: 3.1 - Optimizado para APU Kaveri (driver ati)
# Autor: Asistente de Void Linux
# Licencia: MIT

set -euo pipefail

## Configuración básica
VERSION="3.1"
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

## Funciones de logging
log() {
    local level="$1"
    local message="$2"
    local color
    
    case "$level" in
        "INFO") color="${BLUE}" ;;
        "SUCCESS") color="${GREEN}" ;;
        "WARNING") color="${YELLOW}" ;;
        "ERROR") color="${RED}" ;;
        "STEP") color="${CYAN}" ;;
        *) color="${NC}" ;;
    esac
    
    echo -e "${color}[${level}]${NC} ${message}" | tee -a "$LOG_FILE"
}

## Verificar paquetes antes de instalar
verify_packages() {
    local packages=("$@")
    local missing=()
    
    for pkg in "${packages[@]}"; do
        if ! xbps-query -R "$pkg" &>/dev/null; then
            missing+=("$pkg")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log "ERROR" "Paquetes no encontrados en repositorios: ${missing[*]}"
        return 1
    fi
    return 0
}

## Verificar conexión a Internet
check_internet() {
    log "STEP" "Verificando conexión a Internet..."
    if ! ping -c 1 -W 5 google.com >/dev/null 2>&1 && ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        log "ERROR" "No hay conexión a Internet. Verifica tu conexión."
        exit 1
    fi
    log "SUCCESS" "Conexión a Internet verificada."
}

## Actualizar sistema
update_system() {
    log "STEP" "Actualizando sistema base..."
    sudo xbps-install -Suy 2>&1 | tee -a "$LOG_FILE"
    log "SUCCESS" "Sistema actualizado."
}

## Configurar repositorios
setup_repos() {
    log "STEP" "Configurando repositorios adicionales..."
    
    local repos=(
        "void-repo-nonfree"
        "void-repo-multilib"
        "void-repo-multilib-nonfree"
    )
    
    verify_packages "${repos[@]}" || exit 1
    
    for repo in "${repos[@]}"; do
        if ! sudo xbps-query -l | grep -q "$repo"; then
            sudo xbps-install -y "$repo" 2>&1 | tee -a "$LOG_FILE"
        fi
    done
    
    sudo xbps-install -S 2>&1 | tee -a "$LOG_FILE"
    log "SUCCESS" "Repositorios configurados."
}

## Instalar controladores AMD (Kaveri específico)
install_amd_drivers() {
    log "STEP" "Instalando controladores AMD para Kaveri (xf86-video-ati)..."
    
    local amd_packages=(
        "mesa-dri"
        "xf86-video-ati"       # Driver específico para Kaveri
        "linux-firmware-amd"
        "mesa-vaapi"
        "mesa-vdpau"
        "libva-mesa-driver"
        "vulkan-loader"
    )
    
    verify_packages "${amd_packages[@]}" || exit 1
    sudo xbps-install -y "${amd_packages[@]}" 2>&1 | tee -a "$LOG_FILE"
    
    # Configuración específica para Kaveri
    echo "options radeon si_support=1 cik_support=1" | sudo tee /etc/modprobe.d/radeon.conf
    log "SUCCESS" "Controladores AMD instalados (xf86-video-ati)."
}

## Instalar Xorg (sin Wayland)
install_xorg() {
    log "STEP" "Instalando Xorg (sin Wayland)..."
    
    local xorg_packages=(
        "xorg-minimal"
        "xorg-server"          # Solo Xorg, no Wayland
        "xorg-server-xwayland" # Para compatibilidad opcional
        "xorg-apps"
        "xorg-fonts"
        "xinit"
        "xauth"
        "xsetroot"
        "xrandr"
    )
    
    verify_packages "${xorg_packages[@]}" || exit 1
    sudo xbps-install -y "${xorg_packages[@]}" 2>&1 | tee -a "$LOG_FILE"
    log "SUCCESS" "Xorg instalado (sin Wayland)."
}

## Instalar KDE Plasma (X11 solamente)
install_kde() {
    log "STEP" "Instalando KDE Plasma (X11)..."
    
    # Paquetes base de KDE (X11)
    local kde_base=(
        "plasma-desktop"
        "plasma-workspace"
        "kwin"                 # Compositor X11
        "kde-cli-tools"
        "systemsettings"
        "dolphin"
        "konsole"
        "kate"
        "plasma-nm"
        "plasma-pa"
        "sddm"
        "sddm-kcm"
        "kde-gtk-config"
        "breeze"
        "breeze-gtk"
        "breeze-icons"
    )
    
    # Aplicaciones KDE recomendadas
    local kde_apps=(
        "kcalc"
        "kwrite"
        "gwenview"
        "okular"
        "ark"
        "spectacle"
        "partitionmanager"
        "kdeconnect"
        "print-manager"
        "kscreen"
        "powerdevil"
        "bluedevil"
    )
    
    verify_packages "${kde_base[@]}" "${kde_apps[@]}" || exit 1
    sudo xbps-install -y "${kde_base[@]}" "${kde_apps[@]}" 2>&1 | tee -a "$LOG_FILE"
    
    # Forzar X11 como predeterminado
    sudo bash -c 'echo "export KDE_SESSION_VERSION=5" > /etc/profile.d/kde.sh'
    sudo bash -c 'echo "export XDG_SESSION_TYPE=x11" >> /etc/profile.d/kde.sh'
    log "SUCCESS" "KDE Plasma instalado (X11 solamente)."
}

## Configurar SDDM para X11
configure_sddm() {
    log "STEP" "Configurando SDDM para X11..."
    
    sudo mkdir -p /etc/sddm.conf.d
    cat << EOF | sudo tee /etc/sddm.conf.d/00-x11.conf
[Autologin]
Relogin=false
Session=plasma-x11.desktop
User=

[General]
HaltCommand=/usr/bin/loginctl poweroff
RebootCommand=/usr/bin/loginctl reboot

[Theme]
Current=breeze
EnableAvatars=true

[X11]
ServerPath=/usr/bin/X
DisplayCommand=/usr/share/sddm/scripts/Xsetup
EOF
    
    sudo ln -sf /etc/sv/sddm /var/service/
    log "SUCCESS" "SDDM configurado para X11."
}

## Instalar PipeWire
install_pipewire() {
    log "STEP" "Instalando PipeWire..."
    
    local audio_packages=(
        "pipewire"
        "wireplumber"
        "pipewire-pulse"
        "pipewire-alsa"
        "pipewire-jack"
        "pavucontrol"
        "alsa-utils"
        "rtkit"
    )
    
    verify_packages "${audio_packages[@]}" || exit 1
    sudo xbps-install -y "${audio_packages[@]}" 2>&1 | tee -a "$LOG_FILE"
    
    # Configurar servicios
    sudo ln -sf /etc/sv/rtkit /var/service/
    sudo ln -sf /etc/sv/dbus /var/service/
    sudo usermod -aG audio "$USERNAME"
    
    # Configuración para el usuario
    mkdir -p ~/.config/pipewire
    cp /usr/share/pipewire/client.conf ~/.config/pipewire/
    log "SUCCESS" "PipeWire instalado y configurado."
}

## Instalar aplicaciones esenciales
install_essentials() {
    log "STEP" "Instalando aplicaciones esenciales..."
    
    local essential_packages=(
        "firefox"
        "vlc"
        "libreoffice"
        "neofetch"
        "htop"
        "git"
        "wget"
        "curl"
        "nano"
        "vim"
        "gparted"
        "ntfs-3g"
        "flatpak"
    )
    
    verify_packages "${essential_packages[@]}" || exit 1
    sudo xbps-install -y "${essential_packages[@]}" 2>&1 | tee -a "$LOG_FILE"
    
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    log "SUCCESS" "Aplicaciones esenciales instaladas."
}

## Instalar codecs multimedia
install_codecs() {
    log "STEP" "Instalando codecs multimedia..."
    
    local codec_packages=(
        "ffmpeg"
        "gstreamer1"
        "gstreamer1-plugins-base"
        "gstreamer1-plugins-good"
        "gstreamer1-plugins-bad"
        "gstreamer1-plugins-ugly"
        "gstreamer1-vaapi"
        "gst-libav"
    )
    
    verify_packages "${codec_packages[@]}" || exit 1
    sudo xbps-install -y "${codec_packages[@]}" 2>&1 | tee -a "$LOG_FILE"
    log "SUCCESS" "Codecs multimedia instalados."
}

## Optimizar sistema
optimize_system() {
    log "STEP" "Optimizando sistema para APU Kaveri..."
    
    # Optimización para SSD
    if grep -q '^/dev/sd' /etc/fstab; then
        sudo sed -i 's/\(defaults\)/\1,noatime/' /etc/fstab
    fi
    
    # Configurar swappiness
    echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
    
    # Configurar TTY sin KMS para evitar problemas
    if ! grep -q "radeon.modeset=0" /etc/default/grub; then
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/&radeon.modeset=0 /' /etc/default/grub
        sudo update-grub
    fi
    
    # Limpiar paquetes innecesarios
    sudo xbps-remove -O 2>&1 | tee -a "$LOG_FILE"
    log "SUCCESS" "Sistema optimizado para APU Kaveri."
}

## Crear script de diagnóstico
create_diagnostic() {
    log "STEP" "Creando script de diagnóstico..."
    
    cat > ~/void-kde-diag.sh << 'EOF'
#!/bin/bash
echo "=== DIAGNÓSTICO VOID KDE (Kaveri) ==="
echo "Fecha: $(date)"
echo "===================================="

echo -e "\n[1] Sistema:"
uname -a
cat /etc/os-release

echo -e "\n[2] Gráficos (Kaveri):"
lspci -nn | grep -i "vga\|amd"
glxinfo | grep -i "renderer\|version" || echo "glxinfo no disponible"
dmesg | grep -i "radeon\|drm" | tail -20

echo -e "\n[3] Audio:"
pactl info || echo "PulseAudio no disponible"
pipewire --version || echo "PipeWire no disponible"

echo -e "\n[4] Servicios:"
sv status /var/service/*

echo -e "\n[5] Sesiones disponibles:"
ls /usr/share/xsessions/

echo -e "\n[6] SDDM:"
cat /etc/sddm.conf.d/* 2>/dev/null
systemctl status sddm --no-pager || sv status sddm

echo -e "\n[7] Variables de entorno:"
printenv | grep -E "XDG|QT|KDE|PLASMA|DISPLAY|WAYLAND"

echo -e "\n[8] Xorg:"
cat /var/log/Xorg.0.log | grep -i "EE\|WW\|radeon" | tail -20

echo -e "\n=== FIN DEL DIAGNÓSTICO ==="
EOF
    
    chmod +x ~/void-kde-diag.sh
    log "SUCCESS" "Script de diagnóstico creado: ~/void-kde-diag.sh"
}

## Mostrar resumen final
show_summary() {
    clear
    echo -e "${GREEN}"
    echo "  ██████╗  ██████╗ ██╗██████╗     ██╗  ██╗██████╗ ███████╗"
    echo "  ██╔══██╗██╔═══██╗██║██╔══██╗    ██║ ██╔╝██╔══██╗██╔════╝"
    echo "  ██████╔╝██║   ██║██║██║  ██║    █████╔╝ ██║  ██║█████╗  "
    echo "  ██╔══██╗██║   ██║██║██║  ██║    ██╔═██╗ ██║  ██║██╔══╝  "
    echo "  ██║  ██║╚██████╔╝██║██████╔╝    ██║  ██╗██████╔╝███████╗"
    echo "  ╚═╝  ╚═╝ ╚═════╝ ╚═╝╚═════╝     ╚═╝  ╚═╝╚═════╝ ╚══════╝"
    echo -e "${NC}"
    echo "  Instalación completada exitosamente!"
    echo "  Versión del script: $VERSION"
    echo "  Log completo: $LOG_FILE"
    echo ""
    echo -e "${YELLOW}Configuración específica para APU Kaveri:${NC}"
    echo "  • Driver gráfico: xf86-video-ati"
    echo "  • Kernel mode setting desactivado en TTY (radeon.modeset=0)"
    echo "  • Soporte CIK/SI habilitado"
    echo "  • X11 como sesión predeterminada (no Wayland)"
    echo ""
    echo -e "${YELLOW}Próximos pasos:${NC}"
    echo "  1. Reinicia el sistema: sudo reboot"
    echo "  2. Inicia sesión en KDE Plasma desde SDDM"
    echo "  3. Para diagnóstico: ~/void-kde-diag.sh"
    echo ""
    
    if $REBOOT_NEEDED; then
        echo -e "${RED}¡REINICIO REQUERIDO!${NC}"
        read -p "¿Deseas reiniciar ahora? [s/N]: " choice
        if [[ "$choice" =~ ^[SsYy]$ ]]; then
            sudo reboot
        fi
    fi
}

## Función principal
main() {
    clear
    echo -e "${BLUE}"
    echo "=============================================="
    echo "  Script de Post-Instalación Void Linux + KDE "
    echo "  Versión: $VERSION - Optimizado para Kaveri"
    echo "  Usuario: $USERNAME"
    echo "  Log: $LOG_FILE"
    echo "=============================================="
    echo -e "${NC}"
    
    # Ejecutar pasos de instalación
    check_internet
    update_system
    setup_repos
    install_amd_drivers
    install_xorg
    install_kde
    configure_sddm
    install_pipewire
    install_essentials
    install_codecs
    optimize_system
    create_diagnostic
    
    REBOOT_NEEDED=true
    show_summary
}

## Ejecutar script
main "$@"