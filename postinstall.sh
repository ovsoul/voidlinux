#!/bin/bash

# Script de post-instalación para Void Linux
# KDE Plasma + PipeWire + Optimizaciones AMD APU Kaveri
# Autor: Configuración personalizada para AMD A8-7600B

set -e

echo "=== INICIANDO POST-INSTALACIÓN VOID LINUX + KDE PLASMA ==="
echo "Sistema: AMD A8-7600B (Kaveri APU) - 14GB RAM - SSD"
echo "========================================================="

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[ÉXITO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[ADVERTENCIA]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar si se ejecuta como root
if [[ $EUID -eq 0 ]]; then
   print_error "Este script no debe ejecutarse como root"
   exit 1
fi

# Verificar conexión a internet
print_status "Verificando conexión a internet..."
if ! ping -c 1 google.com > /dev/null 2>&1; then
    print_error "No hay conexión a internet. Verifica tu conexión."
    exit 1
fi
print_success "Conexión a internet verificada"

# Actualizar repositorios
print_status "Actualizando repositorios..."
sudo xbps-install -Su

# Instalar repositorios necesarios
print_status "Habilitando repositorios adicionales..."
sudo xbps-install -y void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree

# Actualizar después de agregar repos
print_status "Actualizando con nuevos repositorios..."
sudo xbps-install -Su

# Instalar controladores AMD para Kaveri (radeon)
print_status "Instalando controladores AMD Radeon para APU Kaveri..."
sudo xbps-install -y \
    mesa-dri \
    xf86-video-ati \
    linux-firmware-amd \
    mesa-vaapi \
    mesa-vdpau \
    libdrm

# Instalar KDE Plasma y aplicaciones esenciales
print_status "Instalando KDE Plasma Desktop..."
sudo xbps-install -y \
    kde5 \
    kde5-baseapps \
    plasma-desktop \
    plasma-workspace \
    plasma-nm \
    plasma-pa \
    konsole \
    dolphin \
    kate \
    gwenview \
    spectacle \
    okular \
    ark \
    kcalc \
    kwrite \
    partitionmanager \
    kinfocenter \
    systemsettings \
    kscreen \
    powerdevil \
    bluedevil \
    kwalletmanager

# Instalar SDDM (Display Manager)
print_status "Instalando y configurando SDDM..."
sudo xbps-install -y sddm
sudo ln -sf /etc/sv/sddm /var/service/

# Instalar PipeWire
print_status "Instalando PipeWire..."
sudo xbps-install -y \
    pipewire \
    pipewire-pulse \
    pipewire-jack \
    pipewire-alsa \
    wireplumber \
    rtkit \
    alsa-utils \
    pavucontrol \
    qpwgraph

# Instalar fuentes
print_status "Instalando fuentes..."
sudo xbps-install -y \
    noto-fonts-ttf \
    noto-fonts-emoji \
    dejavu-fonts-ttf \
    liberation-fonts-ttf \
    font-awesome \
    font-awesome5

# Instalar aplicaciones adicionales útiles
print_status "Instalando aplicaciones adicionales..."
sudo xbps-install -y \
    firefox \
    thunderbird \
    libreoffice \
    gimp \
    vlc \
    neofetch \
    htop \
    git \
    wget \
    curl \
    zip \
    unzip \
    nano \
    vim \
    tree \
    lshw \
    inxi \
    usbutils \
    pciutils

# Instalar codecs multimedia
print_status "Instalando codecs multimedia..."
sudo xbps-install -y \
    gstreamer1-plugins-base \
    gstreamer1-plugins-good \
    gstreamer1-plugins-bad \
    gstreamer1-plugins-ugly \
    gstreamer1-vaapi \
    ffmpeg

# Configurar servicios del sistema
print_status "Configurando servicios del sistema..."

# Habilitar servicios esenciales
sudo ln -sf /etc/sv/dbus /var/service/
sudo ln -sf /etc/sv/polkitd /var/service/
sudo ln -sf /etc/sv/NetworkManager /var/service/
sudo ln -sf /etc/sv/bluetoothd /var/service/

# Configurar PipeWire para el usuario
print_status "Configurando PipeWire para el usuario..."
mkdir -p ~/.config/pipewire
mkdir -p ~/.config/wireplumber

# Crear configuración de PipeWire optimizada para AMD
cat > ~/.config/pipewire/pipewire.conf << 'EOF'
context.properties = {
    default.clock.rate = 44100
    default.clock.quantum = 1024
    default.clock.min-quantum = 32
    default.clock.max-quantum = 8192
}

context.modules = [
    { name = libpipewire-module-rtkit }
    { name = libpipewire-module-protocol-native }
    { name = libpipewire-module-profiler }
    { name = libpipewire-module-metadata }
    { name = libpipewire-module-spa-device-factory }
    { name = libpipewire-module-spa-node-factory }
    { name = libpipewire-module-client-node }
    { name = libpipewire-module-client-device }
    { name = libpipewire-module-portal }
    { name = libpipewire-module-access }
    { name = libpipewire-module-adapter }
    { name = libpipewire-module-link-factory }
    { name = libpipewire-module-session-manager }
]
EOF

# Configurar ALSA para PipeWire
print_status "Configurando ALSA para PipeWire..."
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

# Configurar optimizaciones para SSD
print_status "Aplicando optimizaciones para SSD..."
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf

# Configurar fstab para SSD (si no está ya configurado)
if ! grep -q "noatime" /etc/fstab; then
    print_status "Configurando fstab para SSD..."
    sudo sed -i 's/defaults/defaults,noatime,discard/' /etc/fstab
fi

# Configurar kernel parameters para AMD Kaveri (radeon)
print_status "Configurando parámetros del kernel para AMD Kaveri..."
if [[ -f /etc/default/grub ]]; then
    sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& radeon.dpm=1 radeon.audio=1/' /etc/default/grub
    sudo update-grub
elif [[ -d /boot/loader/entries ]]; then
    # Para sistemas con systemd-boot
    for entry in /boot/loader/entries/*.conf; do
        if [[ -f "$entry" ]]; then
            sudo sed -i '/^options/ s/$/ radeon.dpm=1 radeon.audio=1/' "$entry"
        fi
    done
fi

# Configurar límites de memoria para mejor rendimiento
print_status "Configurando límites de memoria..."
cat << 'EOF' | sudo tee -a /etc/security/limits.conf
@audio - rtprio 95
@audio - memlock unlimited
$USER - rtprio 95
$USER - memlock unlimited
EOF

# Configurar Plasma para mejor rendimiento
print_status "Configurando Plasma para mejor rendimiento..."
mkdir -p ~/.config

# Configuración básica de Plasma
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

[Effect-DesktopGrid]
BorderActivate=9

[Effect-PresentWindows]
BorderActivate=9

[Plugins]
blurEnabled=true
contrastEnabled=true
slideEnabled=true
EOF

# Configurar tema y apariencia
print_status "Configurando tema y apariencia..."
cat > ~/.config/kdeglobals << 'EOF'
[General]
ColorScheme=Breeze
Name=Breeze
shadeSortColumn=true
widgetStyle=Breeze

[Icons]
Theme=breeze

[KDE]
LookAndFeelPackage=org.kde.breeze.desktop
SingleClick=false
EOF

# Configurar panel de Plasma
print_status "Configurando panel de Plasma..."
mkdir -p ~/.config/plasma-org.kde.plasma.desktop-appletsrc

# Instalar y configurar Flatpak (opcional)
print_status "Instalando Flatpak..."
sudo xbps-install -y flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Configurar variables de entorno
print_status "Configurando variables de entorno..."
cat >> ~/.bashrc << 'EOF'

# Configuración PipeWire
export PIPEWIRE_RUNTIME_DIR="${XDG_RUNTIME_DIR}/pipewire"

# Configuración AMD para Kaveri
export MESA_LOADER_DRIVER_OVERRIDE=radeonsi

# Configuración Qt
export QT_QPA_PLATFORMTHEME=kde
export QT_SCALE_FACTOR=1
EOF

# Crear script de inicio personalizado
print_status "Creando script de inicio personalizado..."
mkdir -p ~/.config/autostart

cat > ~/.config/autostart/custom-setup.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Custom Setup
Exec=/bin/bash -c "pipewire & wireplumber &"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

# Configurar servicio de PipeWire para el usuario
print_status "Configurando servicios de usuario..."
mkdir -p ~/.config/systemd/user

# Limpiar caché
print_status "Limpiando caché del sistema..."
sudo xbps-remove -O
sudo xbps-remove -o

# Información final
print_success "¡Instalación completada!"
echo ""
echo "========================================================="
echo -e "${GREEN}RESUMEN DE LA INSTALACIÓN:${NC}"
echo "- KDE Plasma Desktop instalado"
echo "- PipeWire configurado para audio"
echo "- Controladores AMD optimizados"
echo "- Optimizaciones para SSD aplicadas"
echo "- Aplicaciones esenciales instaladas"
echo "- Servicios configurados"
echo ""
echo -e "${YELLOW}PRÓXIMOS PASOS:${NC}"
echo "1. Reinicia el sistema: sudo reboot"
echo "2. Inicia sesión en KDE Plasma"
echo "3. Configura PipeWire desde Configuración del Sistema"
echo "4. Verifica audio con: pactl info"
echo "5. Opcional: Instala aplicaciones adicionales desde Flatpak"
echo ""
echo -e "${BLUE}COMANDOS ÚTILES:${NC}"
echo "- Verificar PipeWire: systemctl --user status pipewire"
echo "- Información del sistema: inxi -Fxz"
echo "- Temperatura GPU: sensors"
echo "- Gestión de paquetes: xbps-query -l | grep <paquete>"
echo ""
print_warning "¡REINICIA EL SISTEMA PARA APLICAR TODOS LOS CAMBIOS!"
echo "========================================================="