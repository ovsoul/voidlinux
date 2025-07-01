#!/bin/bash

# Script de post-instalación para Void Linux - Versión Corregida v3.0
# KDE Plasma + PipeWire + Optimizaciones AMD APU Kaveri
# Corrige el problema de pantalla negra en SDDM

set -euo pipefail

echo "=== POST-INSTALACIÓN VOID LINUX + KDE PLASMA v3.0 ==="
echo "Sistema: AMD A8-7600B (Kaveri APU) - 14GB RAM - SSD"
echo "Versión corregida - Sin pantalla negra en SDDM"
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
        "xf86-video-amdgpu"
        "xf86-video-ati"
        "linux-firmware-amd"
        "mesa-vaapi"
        "mesa-vdpau"
        "libdrm"
        "libva-mesa-driver"
        "mesa-opencl"
        "vulkan-loader"
        "mesa-vulkan-radeon"
    )
    
    install_packages "${amd_packages[@]}"
    
    log_success "Controladores AMD instalados"
}

# Instalar Xorg completo
install_xorg() {
    log_step "Instalando servidor X completo..."
    
    local xorg_packages=(
        "xorg"
        "xorg-apps"
        "xorg-fonts"
        "xorg-input-drivers"
        "xorg-video-drivers"
        "setxkbmap"
        "xauth"
        "xhost"
        "xinit"
        "xrandr"
        "xdpyinfo"
        "mesa-demos"
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
        "noto-fonts-cjk"
        "dejavu-fonts-ttf"
        "liberation-fonts-ttf"
        "font-awesome"
        "font-awesome5"
        "font-awesome6"
        "fonts-roboto-ttf"
        "ttf-ubuntu-font-family"
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
        "alsa-plugins-pulseaudio"
        "pavucontrol"
        "rtkit"
        "pulseaudio-utils"
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
    mkdir -p ~/.config/pipewire/pipewire.conf.d
    mkdir -p ~/.config/wireplumber/main.lua.d
    
    # Configuración básica de PipeWire
    cat > ~/.config/pipewire/pipewire.conf << 'EOF'
context.properties = {
    default.clock.rate = 44100
    default.clock.quantum = 1024
    default.clock.min-quantum = 32
    default.clock.max-quantum = 2048
    default.clock.allowed-rates = [ 44100 48000 ]
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

# Instalar KDE Plasma completo
install_kde_plasma() {
    log_step "Instalando KDE Plasma Desktop completo..."
    
    # Paquetes KDE esenciales
    local kde_essential=(
        "kde5"
        "kde5-baseapps"
        "plasma-desktop"
        "plasma-workspace"
        "plasma-workspace-wallpapers"
        "kwin"
        "systemsettings5"
        "plasma-nm"
        "plasma-pa"
        "kde-cli-tools"
        "khotkeys"
        "kglobalaccel"
        "kactivitymanagerd"
        "kscreen"
        "powerdevil"
        "oxygen"
        "polkit-kde-agent"
    )
    
    log_info "Instalando componentes esenciales de KDE..."
    install_packages "${kde_essential[@]}"
    
    # Aplicaciones KDE básicas
    local kde_apps=(
        "dolphin"
        "konsole"
        "kate"
        "gwenview"
        "spectacle"
        "okular"
        "ark"
        "kcalc"
        "kwrite"
        "partitionmanager"
        "kinfocenter"
        "kwalletmanager5"
        "bluedevil"
        "kwallet-pam"
    )
    
    log_info "Instalando aplicaciones KDE..."
    install_packages "${kde_apps[@]}"
    
    # Temas y decoraciones
    local kde_themes=(
        "breeze"
        "breeze-gtk"
        "breeze-icons"
        "oxygen-icons5"
        "plasma5-themes-extra"
    )
    
    log_info "Instalando temas KDE..."
    install_packages "${kde_themes[@]}"
    
    # Dependencias críticas para sesión
    local kde_deps=(
        "xdg-desktop-portal"
        "xdg-desktop-portal-kde"
        "xdg-user-dirs"
        "xdg-utils"
        "dbus-x11"
        "polkit"
        "udisks2"
        "upower"
    )
    
    log_info "Instalando dependencias de sesión..."
    install_packages "${kde_deps[@]}"
    
    log_success "KDE Plasma instalado completamente"
}

# Instalar SDDM (Display Manager)
install_sddm() {
    log_step "Instalando y configurando SDDM..."
    
    install_packages "sddm"
    
    # Configurar SDDM correctamente
    sudo mkdir -p /etc/sddm.conf.d
    
    cat << EOF | sudo tee /etc/sddm.conf.d/kde.conf
[Autologin]
Relogin=false
Session=plasma
User=

[General]
HaltCommand=/usr/bin/loginctl poweroff
RebootCommand=/usr/bin/loginctl reboot
Numlock=none

[Theme]
Current=breeze
CursorTheme=breeze_cursors
Font=Noto Sans,10,-1,5,50,0,0,0,0,0

[Users]
MaximumUid=60000
MinimumUid=1000
HideUsers=
HideShells=

[X11]
ServerPath=/usr/bin/X
ServerArguments=-nolisten tcp
SessionCommand=/usr/bin/startplasma-x11
SessionDir=/usr/share/xsessions
DisplayCommand=/usr/share/sddm/scripts/Xsetup
DisplayStopCommand=/usr/share/sddm/scripts/Xstop
EOF

    # Crear sesión de escritorio para KDE
    sudo mkdir -p /usr/share/xsessions
    cat << 'EOF' | sudo tee /usr/share/xsessions/plasma.desktop
[Desktop Entry]
Type=XSession
Exec=/usr/bin/startplasma-x11
TryExec=/usr/bin/startplasma-x11
DesktopNames=KDE
Name=Plasma (X11)
Comment=Plasma by KDE
EOF
    
    # Configurar directorio SDDM
    sudo mkdir -p /var/lib/sddm
    sudo chown -R sddm:sddm /var/lib/sddm
    
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
        "rsync"
        "zip"
        "unzip"
        "p7zip"
        "nano"
        "vim"
        "tree"
        "lshw"
        "inxi"
        "usbutils"
        "pciutils"
        "smartmontools"
        "gparted"
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
        "gst-plugins-base1"
        "gst-plugins-good1"
        "gst-plugins-bad1"
        "gst-plugins-ugly1"
        "ffmpeg"
        "x264"
        "x265"
    )
    
    install_packages "${codec_packages[@]}"
    
    log_success "Codecs multimedia instalados"
}

# Configurar servicios del sistema (orden correcto)
configure_system_services() {
    log_step "Configurando servicios del sistema..."
    
    # Deshabilitar servicios conflictivos primero
    disable_service "gdm"
    disable_service "lightdm"
    
    # Servicios base del sistema (orden crítico)
    local base_services=(
        "udevd"
        "dbus"
    )
    
    for service in "${base_services[@]}"; do
        enable_service "$service"
    done
    
    sleep 1
    
    # Servicios de hardware y audio
    local hardware_services=(
        "rtkit"
        "polkitd"
        "udisks2"
        "upower"
    )
    
    for service in "${hardware_services[@]}"; do
        enable_service "$service"
    done
    
    sleep 1
    
    # Servicios de red
    local network_services=(
        "NetworkManager"
        "bluetoothd"
    )
    
    for service in "${network_services[@]}"; do
        enable_service "$service"
    done
    
    sleep 1
    
    # SDDM al final (después de todos los otros servicios)
    enable_service "sddm"
    
    log_success "Servicios del sistema configurados en orden correcto"
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
vm.dirty_expire_centisecs=6000
vm.dirty_writeback_centisecs=500
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
* - nofile 65536
EOF
    
    # Configurar PAM para límites
    if ! grep -q "pam_limits.so" /etc/pam.d/login; then
        echo "session required pam_limits.so" | sudo tee -a /etc/pam.d/login
    fi
    
    log_success "Límites del sistema configurados"
}

# Configurar variables de entorno globales
setup_environment() {
    log_step "Configurando variables de entorno..."
    
    # Variables para el usuario actual
    cat >> ~/.bashrc << 'EOF'

# Configuración para KDE Plasma en Void Linux
export XDG_CURRENT_DESKTOP=KDE
export XDG_SESSION_DESKTOP=KDE
export XDG_SESSION_TYPE=x11
export QT_QPA_PLATFORMTHEME=kde
export QT_SCALE_FACTOR=1
export DESKTOP_SESSION=plasma

# Configuración PipeWire
export PIPEWIRE_RUNTIME_DIR="${XDG_RUNTIME_DIR}/pipewire"

# Configuración AMD Radeon
export MESA_LOADER_DRIVER_OVERRIDE=radeonsi
export AMD_VULKAN_ICD=RADV

# Configuración Qt
export QT_AUTO_SCREEN_SCALE_FACTOR=0
export QT_FONT_DPI=96
EOF
    
    # Configurar perfil del sistema
    cat << 'EOF' | sudo tee /etc/profile.d/kde-session.sh
#!/bin/sh
# Configuración global para KDE Plasma

export XDG_CURRENT_DESKTOP=KDE
export XDG_SESSION_DESKTOP=KDE
export XDG_SESSION_TYPE=x11
export QT_QPA_PLATFORMTHEME=kde
export DESKTOP_SESSION=plasma

# Configuración gráfica AMD
export MESA_LOADER_DRIVER_OVERRIDE=radeonsi
export AMD_VULKAN_ICD=RADV
EOF
    
    sudo chmod +x /etc/profile.d/kde-session.sh
    
    log_success "Variables de entorno configuradas"
}

# Configurar KDE Plasma con configuración mínima funcional
configure_kde_plasma() {
    log_step "Configurando KDE Plasma..."
    
    # Crear directorios de configuración
    mkdir -p ~/.config
    mkdir -p ~/.local/share
    mkdir -p ~/.cache
    
    # Configuración mínima de KWin para evitar problemas
    cat > ~/.config/kwinrc << 'EOF'
[Compositing]
Enabled=true
GLCore=false
HiddenPreviews=5
OpenGLIsUnsafe=false
WindowsBlockCompositing=false

[Effect-Blur]
BlurStrength=5
NoiseStrength=0

[Plugins]
blurEnabled=false
slideEnabled=true
zoomEnabled=false

[Xwayland]
Scale=1
EOF
    
    # Configuración básica de Plasma
    cat > ~/.config/plasmarc << 'EOF'
[Theme]
name=default

[Wallpapers]
usersWallpapers=

[PlasmaViews][Panel 1]
floating=0
EOF
    
    # Configuración de tema global mínima
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
ShowDeleteCommand=true

[KFileDialog Settings]
Allow Expansion=false
Automatically select filename extension=true
Breadcrumb Navigation=true
Decoration position=0
LocationCombo Completionmode=5
PathCombo Completionmode=5
Show Bookmarks=false
Show Full Path=false
Show Speedbar=true
Show hidden files=false
Sort by=Name
Sort directories first=true
Sort reversed=false
Speedbar Width=138
View Style=Simple
EOF
    
    # Configurar autostart básico
    mkdir -p ~/.config/autostart
    
    log_success "KDE Plasma configurado con configuración mínima"
}

# Instalar Flatpak
install_flatpak() {
    log_step "Instalando Flatpak..."
    
    install_packages "flatpak"
    
    # Agregar repositorio Flathub
    if command_exists flatpak; then
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo --user
        log_success "Flatpak instalado y configurado"
    else
        log_warning "Flatpak no se pudo configurar"
    fi
}

# Configurar permisos y grupos de usuario
setup_user_permissions() {
    log_step "Configurando permisos de usuario..."
    
    # Agregar usuario a grupos necesarios
    local user_groups=(
        "audio"
        "video"
        "storage"
        "optical"
        "network"
        "wheel"
        "users"
    )
    
    for group in "${user_groups[@]}"; do
        if getent group "$group" >/dev/null 2>&1; then
            sudo usermod -aG "$group" "$USER_NAME"
            log_info "Usuario agregado al grupo: $group"
        fi
    done
    
    log_success "Permisos de usuario configurados"
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
    
    # Limpiar caché de usuario
    rm -rf ~/.cache/xbps
    
    log_success "Sistema limpiado"
}

# Crear script de diagnóstico mejorado
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
echo ""
cat /etc/os-release

echo -e "\n2. Servicios activos:"
sudo sv status /var/service/* | grep -E "(run|down)"

echo -e "\n3. Display Manager:"
if sudo sv status sddm >/dev/null 2>&1; then
    echo "SDDM: $(sudo sv status sddm)"
else
    echo "SDDM: No instalado"
fi

echo -e "\n4. Información de audio:"
if command -v pipewire >/dev/null 2>&1; then
    echo "PipeWire está instalado"
    if pgrep -x pipewire >/dev/null; then
        echo "PipeWire está ejecutándose"
        pactl info 2>/dev/null | head -5 || echo "PulseAudio no responde"
    else
        echo "PipeWire no está ejecutándose"
    fi
else
    echo "PipeWire no está instalado"
fi

echo -e "\n5. Información gráfica:"
lspci | grep -i vga
lspci | grep -i amd
echo "Driver en uso:"
lspci -k | grep -A2 -i vga
if command -v glxinfo >/dev/null 2>&1; then
    echo "Renderer: $(glxinfo | grep -i renderer | head -1)"
else
    echo "glxinfo no disponible"
fi

echo -e "\n6. Sesiones disponibles:"
ls -la /usr/share/xsessions/ 2>/dev/null || echo "No hay sesiones configuradas"

echo -e "\n7. Variables de entorno importantes:"
echo "XDG_CURRENT_DESKTOP: $XDG_CURRENT_DESKTOP"
echo "XDG_SESSION_DESKTOP: $XDG_SESSION_DESKTOP"
echo "DESKTOP_SESSION: $DESKTOP_SESSION"

echo -e "\n8. Montajes y espacio:"
df -h | grep -E "(Filesystem|/dev/)"

echo -e "\n9. Memoria:"
free -h

echo -e "\n10. Paquetes KDE instalados:"
xbps-query -l | grep -E "(kde5|plasma|sddm)" | wc -l
echo "Total de paquetes KDE encontrados"

echo -e "\n11. Logs recientes (errores):"
dmesg | grep -i error | tail -5

echo -e "\n12. Red:"
ip addr show | grep -E "(inet|UP|DOWN)" | head -10

echo -e "\n13. Procesos KDE:"
pgrep -l plasma || echo "No hay procesos plasma ejecutándose"
pgrep -l kwin || echo "No hay kwin ejecutándose"

echo -e "\n=== FIN DIAGNÓSTICO ==="
EOF
    
    chmod +x ~/void-diagnostic.sh
    log_success "Script de diagnóstico creado en ~/void-diagnostic.sh"
}

# Crear script de inicio manual de KDE (por si falla SDDM)
create_manual_kde_script() {
    log_step "Creando script de inicio manual de KDE..."
    
    cat > ~/start-kde.sh << 'EOF'
#!/bin/bash
# Script para iniciar KDE manualmente desde TTY

echo "Iniciando KDE Plasma manualmente..."

# Configurar variables de entorno
export XDG_CURRENT_DESKTOP=KDE
export XDG_SESSION_DESKTOP=KDE
export XDG_SESSION_TYPE=x11
export QT_QPA_PLATFORMTHEME=kde
export DESKTOP_SESSION=plasma

# Verificar que X esté disponible
if ! command -v startx >/dev/null 2>&1; then
    echo "Error: startx no está disponible"
    exit 1
fi

# Crear .xinitrc temporal si no existe
if [[ ! -f ~/.xinitrc ]]; then
    echo "exec startplasma-x11" > ~/.xinitrc
fi

# Iniciar X con KDE
startx
EOF
    
    chmod +x ~/start-kde.sh
    log_success "Script de inicio manual creado en ~/start-kde.sh"
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
    echo "✓ Servidor X completo configurado"
    echo "✓ KDE Plasma Desktop completo instalado"
    echo "✓ PipeWire (audio) configurado"
    echo "✓ SDDM configurado correctamente"
    echo "✓ Aplicaciones esenciales instaladas"
    echo "✓ Optimizaciones para SSD aplicadas"
    echo "✓ Servicios del sistema configurados"
    echo "✓ Permisos de usuario configurados"
    echo "✓ Flatpak instalado"
    echo "✓ Scripts de diagnóstico creados"
    echo ""
    echo -e "${YELLOW}PRÓXIMOS PASOS:${NC}"
    echo "1. Reinicia el sistema: sudo reboot"
    echo "2. Deberías ver la pantalla de login de SDDM"
    echo "3. Inicia sesión con tu usuario"
    echo "4. KDE Plasma debería cargar automáticamente"
    echo ""
    echo -e "${BLUE}SI SDDM NO FUNCIONA (pantalla negra):${NC}"
    echo "1. Presiona Ctrl+Alt+F2 para ir a TTY2"
    echo "2. Inicia sesión con tu usuario"
    echo "3. Ejecuta: ~/start-kde.sh"
    echo "4. O ejecuta: startx"
    echo ""
    echo -e "${RED}RESOLUCIÓN DE PROBLEMAS:${NC}"
    echo "• Diagnóstico completo: ~/void-diagnostic.sh"
    echo "• Ver servicios: sudo sv status /var/service/*"
    echo "• Reiniciar SDDM: sudo sv restart sddm"
    echo "• Ver logs SDDM: sudo journalctl -u sddm (si está disponible)"
    echo "• Información gráfica: inxi -G"
    echo "• Logs de instalación: cat $LOG_FILE"
    echo ""
    echo -e "${CYAN}CONFIGURACIÓN POST-INSTALACIÓN:${NC}"
    echo "• Configura tu red WiFi desde Configuración del Sistema"
    echo "• Ajusta el audio desde Configuración del Sistema > Audio"
    echo "• Instala aplicaciones desde Discover o Flatpak"
    echo "• Configura el tema y apariencia en Configuración del Sistema"
    echo ""
    echo -e "${GREEN}COMANDOS ÚTILES:${NC}"
    echo "• Información del sistema: neofetch"
    echo "• Monitor del sistema: htop"
    echo "• Información hardware: inxi -Fxz"
    echo "• Gestión de paquetes: xbps-query -l | grep [nombre]"
    echo "• Actualizar sistema: sudo xbps-install -Su"
    echo ""
    
    if [[ $REBOOT_REQUIRED == true ]]; then
        echo -e "${RED}¡REINICIO REQUERIDO!${NC}"
        echo "El sistema necesita reiniciarse para aplicar todos los cambios."
        echo "Después del reinicio, SDDM debería iniciar automáticamente."
        echo ""
        read -p "¿Reiniciar ahora? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Reiniciando sistema..."
            sudo reboot
        else
            echo ""
            echo -e "${YELLOW}Recuerda reiniciar manualmente cuando estés listo.${NC}"
            echo -e "${CYAN}Comando: sudo reboot${NC}"
        fi
    fi
}

# Función principal
main() {
    log_info "Iniciando instalación de KDE Plasma en Void Linux..."
    log_info "Log de instalación: $LOG_FILE"
    
    # Mostrar advertencia inicial
    echo -e "${YELLOW}ADVERTENCIA:${NC} Este script instalará KDE Plasma completo."
    echo "Esto puede tomar 30-60 minutos dependiendo de tu conexión a internet."
    echo ""
    read -p "¿Continuar? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Instalación cancelada."
        exit 0
    fi
    
    # Ejecutar pasos de instalación en orden específico
    initial_checks
    update_system
    setup_repositories
    install_amd_drivers
    install_xorg
    install_fonts
    install_audio
    install_kde_plasma  # KDE completo antes de SDDM
    install_sddm        # SDDM después de KDE
    install_additional_apps
    install_multimedia_codecs
    setup_user_permissions  # Permisos antes de servicios
    configure_system_services  # Servicios en orden correcto
    optimize_for_ssd
    configure_system_limits
    setup_environment
    configure_kde_plasma  # Configuración de KDE al final
    install_flatpak
    cleanup_system
    create_diagnostic_script
    create_manual_kde_script
    
    REBOOT_REQUIRED=true
    show_final_summary
}

# Manejo de señales para limpieza
cleanup_on_exit() {
    log_warning "Instalación interrumpida por el usuario"
    log_info "Limpiando archivos temporales..."
    sudo xbps-remove -O >/dev/null 2>&1 || true
    exit 1
}

# Configurar traps para manejo de señales
trap cleanup_on_exit INT TERM

# Verificar que se ejecuta en Void Linux
if [[ ! -f /etc/os-release ]] || ! grep -q "void" /etc/os-release; then
    log_error "Este script está diseñado específicamente para Void Linux"
    exit 1
fi

# Ejecutar script principal
main "$@"