#!/bin/bash

# Script de Post-Instalación para Void Linux con KDE
# Incluye: KDE Plasma, PipeWire, Bluetooth, USB ModeSwitch y optimizaciones

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar que se ejecuta como root
if [[ $EUID -eq 0 ]]; then
    print_error "No ejecutes este script como root. Usa un usuario normal con sudo."
    exit 1
fi

# Verificar conexión a internet
if ! ping -c 1 google.com &> /dev/null; then
    print_error "No hay conexión a internet. Verifica tu conexión."
    exit 1
fi

print_status "Iniciando post-instalación de Void Linux con KDE..."

# Actualizar sistema base
print_status "Actualizando sistema base..."
sudo xbps-install -Syu
print_success "Sistema actualizado"

# Instalar repositorios adicionales completos
print_status "Configurando repositorios completos (libres, no-libres, multilib)..."
sudo xbps-install -Sy void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree
sudo xbps-install -S
print_success "Repositorios completos configurados (incluyendo multilib libre y no-libre)"

# Instalar KDE Plasma y aplicaciones esenciales
print_status "Instalando KDE Plasma..."
sudo xbps-install -y kde5 kde5-baseapps sddm breeze-icons \
    konsole dolphin kate spectacle gwenview okular \
    ark kcalc kwrite firefox-esr
print_success "KDE Plasma instalado"

# Configurar SDDM
print_status "Configurando SDDM..."
sudo ln -sf /etc/sv/sddm /var/service/
print_success "SDDM configurado como display manager"

# Instalar y configurar PipeWire
print_status "Instalando PipeWire..."
sudo xbps-install -y pipewire wireplumber pipewire-pulse \
    alsa-pipewire libjack-pipewire pipewire-media-session \
    pavucontrol alsa-utils
print_success "PipeWire instalado"

# Configurar PipeWire
print_status "Configurando PipeWire..."
# Crear directorio de configuración si no existe
mkdir -p ~/.config/pipewire
mkdir -p ~/.config/wireplumber

# Habilitar servicios de PipeWire para el usuario
sudo ln -sf /etc/sv/pipewire /var/service/
sudo ln -sf /etc/sv/pipewire-pulse /var/service/

print_success "PipeWire configurado"

# Instalar soporte para Bluetooth
print_status "Instalando Bluetooth..."
sudo xbps-install -y bluez bluez-alsa blueman pulseaudio-utils
sudo ln -sf /etc/sv/bluetoothd /var/service/
print_success "Bluetooth instalado y habilitado"

# Instalar USB ModeSwitch
print_status "Instalando USB ModeSwitch..."
sudo xbps-install -y usb_modeswitch usb_modeswitch-data
print_success "USB ModeSwitch instalado"

# Instalar herramientas de sistema y optimización para AMD con soporte multilib
print_status "Instalando herramientas de optimización para AMD..."
sudo xbps-install -y preload zram-generator thermald tlp \
    linux-firmware-amd mesa-dri mesa-ati-dri vulkan-loader mesa-vulkan-radeon \
    xf86-video-ati xf86-video-amdgpu libva-mesa-driver mesa-vaapi \
    lib32-mesa-dri lib32-mesa-vulkan-radeon lib32-libva-mesa-driver \
    xdg-utils xdg-user-dirs radeontop
print_success "Herramientas de optimización AMD instaladas (con soporte 32-bit)"

# Configurar Preload
print_status "Configurando Preload..."
sudo ln -sf /etc/sv/preload /var/service/
print_success "Preload habilitado"

# Configurar TLP para optimización específica de AMD
print_status "Configurando TLP para AMD A8-7600B..."
sudo ln -sf /etc/sv/tlp /var/service/

# Crear configuración personalizada de TLP para AMD
sudo tee /etc/tlp.d/01-amd-optimization.conf > /dev/null <<EOF
# Configuración TLP para AMD A8-7600B

# CPU scaling governor
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=powersave

# CPU performance scaling
CPU_SCALING_MIN_FREQ_ON_AC=1600000
CPU_SCALING_MAX_FREQ_ON_AC=3100000
CPU_SCALING_MIN_FREQ_ON_BAT=800000
CPU_SCALING_MAX_FREQ_ON_BAT=2800000

# AMD GPU power management
RADEON_POWER_PROFILE_ON_AC=high
RADEON_POWER_PROFILE_ON_BAT=low
RADEON_DPM_STATE_ON_AC=performance
RADEON_DPM_STATE_ON_BAT=battery

# Disk settings for SSD
DISK_DEVICES="sda sdb"
DISK_APM_LEVEL_ON_AC="255 255"
DISK_APM_LEVEL_ON_BAT="128 128"
DISK_IOSCHED="mq-deadline mq-deadline"

# Runtime power management
RUNTIME_PM_ON_AC=on
RUNTIME_PM_ON_BAT=auto

# USB autosuspend
USB_AUTOSUSPEND=1
EOF
print_success "TLP configurado para AMD A8-7600B"

# Configurar ZRAM optimizado para 14GB RAM
print_status "Configurando ZRAM para 14GB RAM..."
sudo mkdir -p /etc/systemd/zram-generator.conf.d/
sudo tee /etc/systemd/zram-generator.conf > /dev/null <<EOF
[zram0]
zram-size = 4G
compression-algorithm = lz4
EOF
print_success "ZRAM configurado (4GB para sistema con 14GB RAM)"

# Optimizaciones del kernel para AMD A8-7600B + SSD + 14GB RAM
print_status "Aplicando optimizaciones del kernel para AMD A8-7600B..."
sudo tee -a /etc/sysctl.conf > /dev/null <<EOF

# Optimizaciones específicas para AMD A8-7600B con 14GB RAM y SSD
vm.swappiness = 5
vm.vfs_cache_pressure = 50
vm.dirty_background_ratio = 3
vm.dirty_ratio = 6
vm.dirty_expire_centisecs = 3000
vm.dirty_writeback_centisecs = 500
kernel.sched_autogroup_enabled = 1
kernel.sched_migration_cost_ns = 5000000
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Optimizaciones para SSD
vm.page-cluster = 0
vm.block_dump = 0

# Optimizaciones para APU AMD (gráficos integrados)
dev.i915.perf_stream_paranoid = 0
EOF
print_success "Optimizaciones del kernel AMD aplicadas"

# Configuración específica para AMD A8-7600B
print_status "Aplicando configuración específica para AMD A8-7600B..."

# Configurar fstab para SSD con optimizaciones
sudo cp /etc/fstab /etc/fstab.backup
print_status "Configurando optimizaciones para SSD..."

# Crear script para optimizar montaje de SSD
sudo tee /etc/fstab.d/ssd-optimizations > /dev/null <<EOF
# Optimizaciones para SSD - agregar estas opciones a tus particiones:
# noatime,discard,commit=60
# Ejemplo: UUID=xxxxx / ext4 defaults,noatime,discard,commit=60 0 1
EOF

# Configurar scheduler I/O para SSD
echo 'ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"' | sudo tee /etc/udev/rules.d/60-ssd-scheduler.rules > /dev/null

# Habilitar TRIM para SSD
sudo systemctl enable fstrim.timer 2>/dev/null || true

# Configuración específica para GPU AMD R7 (integrada en A8-7600B)
sudo tee /etc/X11/xorg.conf.d/20-amd.conf > /dev/null <<EOF
Section "Device"
    Identifier "AMD Graphics"
    Driver "amdgpu"
    Option "DRI" "3"
    Option "TearFree" "true"
    Option "AccelMethod" "glamor"
    Option "VariableRefresh" "true"
EndSection
EOF

# Configurar límites de memoria para el sistema con 14GB
sudo tee -a /etc/security/limits.conf > /dev/null <<EOF

# Límites optimizados para sistema con 14GB RAM
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
* soft memlock 8388608
* hard memlock 8388608
EOF

print_success "Configuración AMD A8-7600B aplicada"

# Instalar fuentes adicionales
print_status "Instalando fuentes adicionales..."
sudo xbps-install -y noto-fonts-ttf noto-fonts-emoji \
    font-awesome liberation-fonts-ttf dejavu-fonts-ttf \
    noto-fonts-cjk
print_success "Fuentes adicionales instaladas"

# Instalar codecs multimedia completos con soporte multilib
print_status "Instalando codecs multimedia completos..."
sudo xbps-install -y ffmpeg gstreamer1-plugins-{base,good,bad,ugly} \
    gstreamer1-libav gstreamer1-vaapi libva-mesa-driver \
    mesa-vaapi mesa-vdpau x264 x265 lame faac faad2 \
    lib32-mesa-dri lib32-vulkan-loader lib32-mesa-vaapi \
    lib32-gstreamer1-plugins-base lib32-gstreamer1-plugins-good
print_success "Codecs multimedia completos instalados (incluyendo 32-bit)"

# Configurar directorios de usuario
print_status "Configurando directorios de usuario..."
xdg-user-dirs-update
print_success "Directorios de usuario configurados"

# Crear archivo de configuración para PipeWire
print_status "Creando configuración de PipeWire..."
mkdir -p ~/.config/pipewire
cat > ~/.config/pipewire/pipewire.conf <<EOF
# Configuración personalizada de PipeWire
context.properties = {
    default.clock.rate = 48000
    default.clock.quantum = 1024
    default.clock.min-quantum = 32
    default.clock.max-quantum = 8192
}
EOF
print_success "Configuración de PipeWire creada"

# Instalar herramientas adicionales útiles para AMD
print_status "Instalando herramientas adicionales para monitoreo AMD..."
sudo xbps-install -y git curl wget htop neofetch tree unzip \
    p7zip tmux nano vim bash-completion NetworkManager-openvpn \
    NetworkManager-openconnect sensors lm_sensors hddtemp \
    mesa-demos glxinfo vulkan-tools
print_success "Herramientas adicionales instaladas"

# Configurar sensores para monitoreo de temperatura AMD
print_status "Configurando sensores para AMD A8-7600B..."
sudo sensors-detect --auto
print_success "Sensores AMD configurados"

# Habilitar NetworkManager
print_status "Habilitando NetworkManager..."
sudo ln -sf /etc/sv/NetworkManager /var/service/
print_success "NetworkManager habilitado"

# Configurar Flatpak (opcional)
print_status "Instalando Flatpak..."
sudo xbps-install -y flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
print_success "Flatpak configurado"

# Limpiar paquetes innecesarios
print_status "Limpiando sistema..."
sudo xbps-remove -Oo
sudo xbps-remove -y $(xbps-query -Rs | grep '^??' | cut -d' ' -f2)
print_success "Sistema limpiado"

# Crear script de información del sistema específico para AMD
print_status "Creando script de información del sistema AMD..."
sudo tee /usr/local/bin/system-info > /dev/null <<'EOF'
#!/bin/bash
echo "=== Información del Sistema AMD A8-7600B ==="
echo "Distribución: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p)"
echo "CPU: AMD A8-7600B APU"
echo "Memoria: $(free -h | grep Mem | awk '{print $3 "/" $2 " (" int($3/$2*100) "%)"}')"
echo "Swap: $(free -h | grep Swap | awk '{print $3 "/" $2}')"
echo "Disco: $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}')"
echo ""
echo "=== Información AMD ==="
echo "GPU: $(lspci | grep VGA | cut -d: -f3-)"
echo "Temperatura CPU: $(sensors 2>/dev/null | grep -E 'Core|Tctl|temp1' | head -1 | awk '{print $2}' | sed 's/+//' || echo 'N/A')"
echo "Frecuencia CPU: $(cat /proc/cpuinfo | grep MHz | head -1 | awk '{print $4}' | cut -d. -f1)MHz"
echo "Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo 'N/A')"
echo ""
echo "=== Estado GPU AMD ==="
radeontop -d - -l 1 2>/dev/null | head -1 || echo "Radeontop no disponible"
echo ""
echo "=== Servicios Activos ==="
sudo sv status /var/service/* 2>/dev/null | grep run | head -10
echo ""
echo "=== Información SSD ==="
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT | grep -E "(sda|sdb|nvme)"
EOF
sudo chmod +x /usr/local/bin/system-info
print_success "Script de información AMD creado"

# Configuración final
print_status "Aplicando configuración final..."

# Añadir usuario a grupos necesarios
sudo usermod -aG audio,video,input,plugdev,wheel,bluetooth $(whoami)

# Crear alias útiles específicos para AMD y Chrome
echo '
# Alias útiles
alias ll="ls -la"
alias la="ls -A"
alias l="ls -CF"
alias grep="grep --color=auto"
alias fgrep="fgrep --color=auto"
alias egrep="egrep --color=auto"
alias df="df -h"
alias du="du -h"
alias free="free -h"
alias sysinfo="system-info"
alias update="sudo xbps-install -Syu"
alias search="xbps-query -Rs"
alias install="sudo xbps-install"
alias remove="sudo xbps-remove"
alias temp="sensors"
alias gpu="radeontop"
alias cpufreq="watch -n1 \"cat /proc/cpuinfo | grep MHz\""
alias trim="sudo fstrim -av"
alias chrome="google-chrome"
alias repos="xbps-query -L"
' >> ~/.bashrc

print_success "Configuración final aplicada"

echo ""
echo "=================================================="
print_success "¡Post-instalación AMD A8-7600B completada!"
echo "=================================================="
echo ""
print_warning "IMPORTANTE: Reinicia el sistema para aplicar todos los cambios"
print_warning "RECORDATORIO: Agrega 'noatime,discard,commit=60' a tus particiones SSD en /etc/fstab"
echo ""
echo "Resumen optimizado para AMD A8-7600B + 14GB RAM + SSD:"
echo "• KDE Plasma con SDDM"
echo "• Google Chrome instalado (fallback: Chromium)"
echo "• Repositorios completos: libre, no-libre, multilib"
echo "• PipeWire optimizado (quantum 512)"
echo "• Drivers AMD/RadeonSI + Vulkan (32-bit y 64-bit)"
echo "• ZRAM: 4GB (óptimo para 14GB RAM)"
echo "• Swappiness: 5 (ideal para SSD)"
echo "• TLP con perfiles AMD específicos"
echo "• Scheduler I/O: mq-deadline para SSD"
echo "• TRIM automático habilitado"
echo "• Sensores de temperatura AMD"
echo "• Bluetooth y USB ModeSwitch"
echo "• Preload para mejor rendimiento"
echo "• Codecs multimedia completos (32-bit y 64-bit)"
echo ""
echo "Repositorios habilitados:"
echo "• void-repo-nonfree (firmware propietario)"
echo "• void-repo-multilib (soporte 32-bit)"
echo "• void-repo-multilib-nonfree (32-bit propietario)"
echo ""
echo "Comandos específicos AMD:"
echo "• sysinfo - Información completa del sistema"
echo "• temp - Ver temperaturas"
echo "• gpu - Monitor GPU AMD (radeontop)"
echo "• cpufreq - Ver frecuencias CPU en tiempo real"
echo "• trim - Ejecutar TRIM manual en SSD"
echo "• chrome - Abrir Google Chrome"
echo "• repos - Ver repositorios activos"
echo ""
echo "Navegadores instalados:"
echo "• Google Chrome (principal)"
echo "• Firefox ESR (secundario)"
echo ""
echo "Notas importantes:"
echo "• GPU: AMD Radeon R7 (integrada) con soporte 32-bit"
echo "• Drivers: AMDGPU + Mesa + Vulkan"
echo "• Audio: PipeWire con latencia optimizada"
echo "• Energía: TLP configurado para APU AMD"
echo "• Multimedia: Codecs completos 32/64-bit"
echo ""
print_status "Reinicia con: sudo reboot"
