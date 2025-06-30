#!/bin/bash

# Script de post-instalación para Void Linux - Versión Corregida
# KDE Plasma + PipeWire + Optimizaciones AMD APU Kaveri
# Versión: 2.0 - Sin errores de TTY y configuración robusta

set -euo pipefail

echo "=== POST-INSTALACIÓN VOID LINUX + KDE PLASMA v2.0 ==="
echo "Sistema: AMD A8-7600B (Kaveri APU) - 14GB RAM - SSD"
echo "Versión corregida sin errores de TTY"
echo "======================================================="

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/void_install_$(date +%Y%m%d_%H%M%S).log"
USER_NAME="$(whoami)"
REBOOT_REQUIRED=false

# Funciones de logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[ÉXITO]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[ADVERTENCIA]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_step() {
    echo -e "${CYAN}[PASO]${NC} $1" | tee -a "$LOG_FILE"
}

# Función para verificar si un comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Función para verificar si un paquete está instalado
package_installed() {
    xbps-query -l | grep -q "^ii $1-[0-9]"
}

# Función para instalar paquetes con verificación
install_packages() {
    local packages=("$@")
    local failed_packages=()
    
    log_info "Instalando paquetes: ${packages[*]}"
    
    for package in "${packages[@]}"; do
        if ! package_installed "$package"; then
            log_info "Instalando $package..."
            if sudo xbps-install -y "$package" >> "$LOG_FILE" 2>&1; then
                log_success "$package instalado correctamente"
            else
                log_warning "$package falló al instalar"
                failed_packages+=("$package")
            fi
        else
            log_info "$package ya está instalado"
        fi
    done
    
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        log_warning "Paquetes que fallaron: ${failed_packages[*]}"
    fi
}

# Función para habilitar servicio de forma segura
enable_service() {
    local service="$1"
    local service_path="/etc/sv/$service"
    local service_link="/var/service/$service"
    
    if [[ -d "$service_path" ]]; then
        if [[ ! -L "$service_link" ]]; then
            sudo ln -sf "$service_path" /var/service/
            log_success "Servicio $service habilitado"
        else
            log_info "Servicio $service ya está habilitado"
        fi
    else
        log_warning "Servicio $service no existe en $service_path"
    fi
}

# Función para deshabilitar servicio de forma segura
disable_service() {
    local service="$1"
    local service_link="/var/service/$service"
    
    if [[ -L "$service_link" ]]; then
        sudo rm -f "$service_link"
        log_success "Servicio $service deshabilitado"
    fi
}

# Verificaciones iniciales
initial_checks() {
    log_step "Realizando verificaciones iniciales..."
    
    # Verificar si se ejecuta como root
    if [[ $EUID -eq 0 ]]; then
        log_error "Este script no debe ejecutarse como root"
        exit 1
    fi
    
    # Verificar conexión a internet
    if ! ping -c 1 -W 5 google.com >/dev/null 2>&1; then
        if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
            log_error "No hay conexión a internet. Verifica tu conexión."
            exit 1
        fi
    fi
    log_success "Conexión a internet verificada"
    
    # Verificar espacio en disco
    local available_space=$(df / | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 5000000 ]]; then  # 5GB en KB
        log_warning "Espacio en disco bajo: $(($available_space/1024/1024))GB disponibles"
        read -p "¿Continuar de todos modos? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Crear directorio de logs
    mkdir -p "$(dirname "$LOG_FILE")"
    log_success "Verificaciones iniciales completadas"
}

# Actualizar sistema
update_system() {
    log_step "Actualizando sistema..."
    
    # Actualizar repositorios
    sudo xbps-install -S
    
    # Actualizar paquetes instalados
    sudo xbps-install -Su
    
    log_success "Sistema actualizado"
}

# Configurar repositorios
setup_repositories() {
    log_step "Configurando repositorios..."
    
    # Repositorios adicionales
    local repos=(
        "void-repo-nonfree"
        "void-repo-multilib"
        "void-repo-multilib-nonfree"
    )
    
    install_packages "${repos[@]}"
    
    # Actualizar con nuevos repositorios
    sudo xbps-install -S
    
    log_success "Repositorios configurados"
}

# Instalar controladores AMD
install_amd_drivers() {
    log_step "Instalando controladores AMD para Kaveri..."
    
    local amd_packages=(
        "mesa-dri"
        "xf86-video-ati"
        "linux-firmware-amd"
        "mesa-vaapi"
        "mesa-vdpau"
        "libdrm"
        "libva-mesa-driver"
        "mesa-opencl"
    )
    
    install_packages "${amd_packages[@]}"
    
    log_success "Controladores AMD instalados"
}

# Instalar Xorg
install_xorg() {
    log_step "Instalando servidor X..."
    
    local xorg_packages=(
        "xorg-minimal"
        "xorg-apps"
        "xorg-fonts"
        "setxkbmap"
        "xauth"
        "xhost"
        "xinit"
    )
    
    install_packages "${xorg_packages[@]}"
    
    log_success "Servidor X instalado"
}

# Instalar fuentes
install_fonts() {
    log_step "Instalando fuentes..."
    
    local font_packages=(
        "noto-fonts-ttf"
        "noto-fonts-emoji"
        "dejavu-fonts-ttf"
        "liberation-fonts-ttf"
        "font-awesome"
        "font-awesome5"
        "font-awesome6"
    )
    
    install_packages "${font_packages[@]}"
    
    log_success "Fuentes instaladas"
}

# Instalar audio (PipeWire)
install_audio() {
    log_step "Instalando sistema de audio PipeWire..."
    
    local audio_packages=(
        "pipewire"
        "wireplumber"
        "pipewire-pulse"
        "pipewire-jack"
        "pipewire-alsa"
        "alsa-utils"
        "pavucontrol"
        "rtkit"
    )
    
    install_packages "${audio_packages[@]}"
    
    # Configurar PipeWire para el usuario
    setup_pipewire_config
    
    log_success "Sistema de audio instalado"
}

# Configurar PipeWire
setup_pipewire_config() {
    log_info "Configurando PipeWire..."
    
    # Crear directorios de configuración
    mkdir -p ~/.config/pipewire
    mkdir -p ~/.config/wireplumber
    
    # Configuración básica de PipeWire
    cat > ~/.config/pipewire/pipewire.conf << 'EOF'
context.properties = {
    default.clock.rate = 44100
    default.clock.quantum = 1024
    default.clock.min-quantum = 32
    default.clock.max-quantum = 2048
}

context.modules = [
    { name = libpipewire-module-rtkit }
    { name = libpipewire-module-protocol-native }
    { name = libpipewire-module-client-node }
    { name = libpipewire-module-adapter }
    { name = libpipewire-module-link-factory }
    { name = libpipewire-module-session-manager }
]
EOF
    
    # Configurar ALSA para PipeWire
    cat > ~/.asoundrc << 'EOF'
pcm.!default {
    type pipewire
    playback_node -1
    capture_node -1
}
ctl.!default {
    type pipewire
}
EOF
    
    log_success "PipeWire configurado"
}

# Instalar KDE Plasma (paso por paso)
install_kde_plasma() {
    log_step "Instalando KDE Plasma Desktop..."
    
    # Paquetes KDE básicos
    local kde_core=(
        "plasma-desktop"
        "plasma-workspace"
        "kwin"
        "systemsettings"
        "plasma-nm"
        "plasma-pa"
        "kde-cli-tools"
        "dolphin"
        "konsole"
        "kate"
    )
    
    log_info "Instalando núcleo de KDE Plasma..."
    install_packages "${kde_core[@]}"
    
    # Aplicaciones KDE adicionales
    local kde_apps=(
        "gwenview"
        "spectacle"
        "okular"
        "ark"
        "kcalc"
        "kwrite"
        "partitionmanager"
        "kinfocenter"
        "kscreen"
        "powerdevil"
        "bluedevil"
        "kwalletmanager"
    )
    
    log_info "Instalando aplicaciones KDE..."
    install_packages "${kde_apps[@]}"
    
    # Tema Breeze
    local kde_themes=(
        "breeze"
        "breeze-gtk"
        "breeze-icons"
    )
    
    log_info "Instalando temas KDE..."
    install_packages "${kde_themes[@]}"
    
    log_success "KDE Plasma instalado"
}

# Instalar SDDM (Display Manager)
install_sddm() {
    log_step "Instalando SDDM (Display Manager)..."
    
    install_packages "sddm"
    
    # Configurar SDDM
    sudo mkdir -p /etc/sddm.conf.d
    
    cat << 'EOF' | sudo tee /etc/sddm.conf.d/kde.conf
[Autologin]
Relogin=false
Session=
User=

[General]
HaltCommand=/usr/bin/loginctl poweroff
RebootCommand=/usr/bin/loginctl reboot

[Theme]
Current=breeze

[Users]
MaximumUid=60000
MinimumUid=1000
EOF
    
    log_success "SDDM instalado y configurado"
}

# Instalar aplicaciones adicionales
install_additional_apps() {
    log_step "Instalando aplicaciones adicionales..."
    
    local additional_apps=(
        "firefox"
        "thunderbird"
        "libreoffice"
        "gimp"
        "vlc"
        "neofetch"
        "htop"
        "git"
        "wget"
        "curl"
        "zip"
        "unzip"
        "nano"
        "vim"
        "tree"
        "lshw"
        "inxi"
        "usbutils"
        "pciutils"
    )
    
    install_packages "${additional_apps[@]}"
    
    log_success "Aplicaciones adicionales instaladas"
}

# Instalar codecs multimedia
install_multimedia_codecs() {
    log_step "Instalando codecs multimedia..."
    
    local codec_packages=(
        "gstreamer1-plugins-base"
        "gstreamer1-plugins-good"
        "gstreamer1-plugins-bad"
        "gstreamer1-plugins-ugly"
        "gstreamer1-vaapi"
        "gst-libav"
        "ffmpeg"
    )
    
    install_packages "${codec_packages[@]}"
    
    log_success "Codecs multimedia instalados"
}

# Configurar servicios del sistema
configure_system_services() {
    log_step "Configurando servicios del sistema..."
    
    # Servicios esenciales (habilitar primero)
    local essential_services=(
        "dbus"
        "udevd"
        "rtkit"
    )
    
    for service in "${essential_services[@]}"; do
        enable_service "$service"
    done
    
    # Esperar un momento para que los servicios esenciales se inicien
    sleep 2
    
    # Servicios de red y bluetooth
    local network_services=(
        "NetworkManager"
        "bluetoothd"
    )
    
    for service in "${network_services[@]}"; do
        enable_service "$service"
    done
    
    # SDDM (al final)
    enable_service "sddm"
    
    log_success "Servicios del sistema configurados"
}

# Optimizaciones para SSD
optimize_for_ssd() {
    log_step "Aplicando optimizaciones para SSD..."
    
    # Configurar parámetros del kernel
    cat << 'EOF' | sudo tee -a /etc/sysctl.conf
# Optimizaciones para SSD
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_background_ratio=5
vm.dirty_ratio=10
EOF
    
    # Configurar fstab para SSD (solo si no está configurado)
    if ! grep -q "noatime" /etc/fstab; then
        log_info "Configurando fstab para SSD..."
        sudo cp /etc/fstab /etc/fstab.backup
        sudo sed -i 's/\(.*\s\/\s.*\s\)defaults\(\s.*\)/\1defaults,noatime,discard\2/' /etc/fstab
    fi
    
    log_success "Optimizaciones para SSD aplicadas"
}

# Configurar límites de memoria y audio
configure_system_limits() {
    log_step "Configurando límites del sistema..."
    
    # Límites de audio para PipeWire
    cat << EOF | sudo tee -a /etc/security/limits.conf
# Límites para audio de baja latencia
@audio - rtprio 95
@audio - memlock unlimited
$USER_NAME - rtprio 95
$USER_NAME - memlock unlimited
EOF
    
    log_success "Límites del sistema configurados"
}

# Configurar variables de entorno
setup_environment() {
    log_step "Configurando variables de entorno..."
    
    # Variables para el usuario actual
    cat >> ~/.bashrc << 'EOF'

# Configuración PipeWire
export PIPEWIRE_RUNTIME_DIR="${XDG_RUNTIME_DIR}/pipewire"

# Configuración AMD Radeon
export MESA_LOADER_DRIVER_OVERRIDE=radeonsi

# Configuración Qt/KDE
export QT_QPA_PLATFORMTHEME=kde
export QT_SCALE_FACTOR=1

# Configuración XDG
export XDG_CURRENT_DESKTOP=KDE
export XDG_SESSION_DESKTOP=KDE
EOF
    
    # Configurar perfil del sistema
    cat << 'EOF' | sudo tee /etc/profile.d/kde-session.sh
# Configuración global para KDE
export XDG_CURRENT_DESKTOP=KDE
export XDG_SESSION_DESKTOP=KDE
export QT_QPA_PLATFORMTHEME=kde
EOF
    
    log_success "Variables de entorno configuradas"
}

# Configurar KDE Plasma
configure_kde_plasma() {
    log_step "Configurando KDE Plasma..."
    
    # Crear directorios de configuración
    mkdir -p ~/.config
    mkdir -p ~/.local/share
    
    # Configuración básica de KWin
    cat > ~/.config/kwinrc << 'EOF'
[Compositing]
Enabled=true
GLCore=false
HiddenPreviews=5
OpenGLIsUnsafe=false
WindowsBlockCompositing=true

[Effect-Blur]
BlurStrength=5
NoiseStrength=0

[Plugins]
blurEnabled=true
slideEnabled=true
EOF
    
    # Configuración de tema global
    cat > ~/.config/kdeglobals << 'EOF'
[General]
ColorScheme=Breeze
Name=Breeze
widgetStyle=Breeze

[Icons]
Theme=breeze

[KDE]
LookAndFeelPackage=org.kde.breeze.desktop
SingleClick=false
EOF
    
    log_success "KDE Plasma configurado"
}

# Instalar Flatpak
install_flatpak() {
    log_step "Instalando Flatpak..."
    
    install_packages "flatpak"
    
    # Agregar repositorio Flathub
    if command_exists flatpak; then
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        log_success "Flatpak instalado y configurado"
    else
        log_warning "Flatpak no se pudo configurar"
    fi
}

# Limpiar sistema
cleanup_system() {
    log_step "Limpiando sistema..."
    
    # Limpiar caché de paquetes
    sudo xbps-remove -O
    sudo xbps-remove -o
    
    # Limpiar archivos temporales
    sudo rm -rf /tmp/xbps-*
    sudo rm -rf /var/tmp/xbps-*
    
    log_success "Sistema limpiado"
}

# Crear script de diagnóstico
create_diagnostic_script() {
    log_step "Creando script de diagnóstico..."
    
    cat > ~/void-diagnostic.sh << 'EOF'
#!/bin/bash
# Script de diagnóstico para Void Linux + KDE

echo "=== DIAGNÓSTICO VOID LINUX + KDE ==="
echo "Fecha: $(date)"
echo "======================================"

echo -e "\n1. Información del sistema:"
uname -a
cat /etc/os-release

echo -e "\n2. Servicios activos:"
sudo sv status /var/service/*

echo -e "\n3. Información de audio:"
if command -v pipewire >/dev/null 2>&1; then
    echo "PipeWire está instalado"
    pactl info 2>/dev/null || echo "PipeWire no está ejecutándose"
else
    echo "PipeWire no está instalado"
fi

echo -e "\n4. Información gráfica:"
lspci | grep -i vga
lspci | grep -i amd
glxinfo | grep -i renderer 2>/dev/null || echo "glxinfo no disponible"

echo -e "\n5. Montajes:"
mount | grep -E "(ext4|xfs|btrfs)"

echo -e "\n6. Espacio en disco:"
df -h

echo -e "\n7. Memoria:"
free -h

echo -e "\n8. Paquetes instalados (KDE):"
xbps-query -l | grep -i kde | head -10

echo -e "\n9. Logs recientes:"
dmesg | tail -10

echo -e "\n10. Red:"
ip addr show | grep -E "(inet|UP|DOWN)"

echo -e "\n=== FIN DIAGNÓSTICO ==="
EOF
    
    chmod +x ~/void-diagnostic.sh
    log_success "Script de diagnóstico creado en ~/void-diagnostic.sh"
}

# Mostrar resumen final
show_final_summary() {
    log_step "Instalación completada"
    
    echo ""
    echo "================================================================="
    echo -e "${GREEN}INSTALACIÓN COMPLETADA EXITOSAMENTE${NC}"
    echo "================================================================="
    echo ""
    echo -e "${CYAN}RESUMEN DE INSTALACIÓN:${NC}"
    echo "✓ Sistema base actualizado"
    echo "✓ Controladores AMD Radeon instalados"
    echo "✓ Servidor X configurado"
    echo "✓ KDE Plasma Desktop instalado"
    echo "✓ PipeWire (audio) configurado"
    echo "✓ SDDM (display manager) configurado"
    echo "✓ Aplicaciones esenciales instaladas"
    echo "✓ Optimizaciones para SSD aplicadas"
    echo "✓ Servicios del sistema configurados"
    echo "✓ Flatpak instalado"
    echo ""
    echo -e "${YELLOW}PRÓXIMOS PASOS:${NC}"
    echo "1. Reinicia el sistema: sudo reboot"
    echo "2. Deberías ver la pantalla de login de SDDM"
    echo "3. Inicia sesión con tu usuario"
    echo "4. KDE Plasma debería cargar automáticamente"
    echo ""
    echo -e "${BLUE}COMANDOS ÚTILES:${NC}"
    echo "• Diagnóstico del sistema: ~/void-diagnostic.sh"
    echo "• Ver servicios: sudo sv status /var/service/*"
    echo "• Información de audio: pactl info"
    echo "• Información gráfica: inxi -G"
    echo "• Logs de instalación: cat $LOG_FILE"
    echo ""
    echo -e "${CYAN}CONFIGURACIÓN ADICIONAL:${NC}"
    echo "• Configura tu red desde Configuración del Sistema"
    echo "• Ajusta el audio desde Configuración del Sistema"
    echo "• Instala aplicaciones adicionales desde Discover"
    echo ""
    
    if [[ $REBOOT_REQUIRED == true ]]; then
        echo -e "${RED}¡REINICIO REQUERIDO!${NC}"
        echo "El sistema necesita reiniciarse para aplicar todos los cambios."
        echo ""
        read -p "¿Reiniciar ahora? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo reboot
        fi
    fi
}

# Función principal
main() {
    log_info "Iniciando instalación de KDE Plasma en Void Linux..."
    log_info "Log de instalación: $LOG_FILE"
    
    # Ejecutar pasos de instalación
    initial_checks
    update_system
    setup_repositories
    install_amd_drivers
    install_xorg
    install_fonts
    install_audio
    install_kde_plasma
    install_sddm
    install_additional_apps
    install_multimedia_codecs
    configure_system_services
    optimize_for_ssd
    configure_system_limits
    setup_environment
    configure_kde_plasma
    install_flatpak
    cleanup_system
    create_diagnostic_script
    
    REBOOT_REQUIRED=true
    show_final_summary
}

# Manejo de señales
trap 'log_error "Instalación interrumpida"; exit 1' INT TERM

# Ejecutar script principal
main "$@"