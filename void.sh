#!/bin/bash
# Script de optimización AMD A8-7600B para Void Linux - Versión Segura
# Procesador: AMD A8-7600B APU con gráficos Radeon R7 (Kaveri)
# RAM: 14GB DDR3 | Almacenamiento: SSD

echo "=== OPTIMIZACIÓN SEGURA AMD A8-7600B VOID LINUX ==="
echo "Hardware: AMD A8-7600B APU Kaveri | Radeon R7 | 14GB DDR3 | SSD"

# Verificar que se ejecuta como usuario normal
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: No ejecutes este script como root. Ejecuta como usuario normal."
    exit 1
fi

# Funciones de logging con colores
log_step() {
    echo -e "\n\033[1;34m=== $1 ===\033[0m"
}

log_success() {
    echo -e "\033[1;32m✓ $1\033[0m"
}

log_error() {
    echo -e "\033[1;31m✗ $1\033[0m"
}

log_warning() {
    echo -e "\033[1;33m⚠ $1\033[0m"
}

log_info() {
    echo -e "\033[1;36mℹ $1\033[0m"
}

log_optimization() {
    echo -e "\033[1;35m🚀 $1\033[0m"
}

# Variables del sistema
USER_NAME=$(whoami)
BACKUP_DIR="/tmp/void_optimization_backup_$(date +%Y%m%d_%H%M%S)"
NEEDS_REBOOT=false
IN_GRAPHICAL_SESSION=false

# Detectar sesión gráfica
if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
    IN_GRAPHICAL_SESSION=true
fi

# Crear directorio de backup
mkdir -p "$BACKUP_DIR"

log_step "INFORMACIÓN DEL SISTEMA"
echo "Usuario: $USER_NAME"
echo "Sesión gráfica: $IN_GRAPHICAL_SESSION"
echo "Kernel: $(uname -r)"
echo "Backup en: $BACKUP_DIR"

# Verificar hardware
echo ""
echo "Hardware gráfico detectado:"
lspci | grep -i vga
echo ""
echo "Información CPU:"
lscpu | grep -E "(Model name|CPU MHz|Cache)"

# =============================================
# FASE 1: CONFIGURACIÓN DE REPOSITORIOS
# =============================================

log_step "CONFIGURACIÓN DE REPOSITORIOS"

# Backup del archivo de repositorios
if [ -f /etc/xbps.d/00-repository-main.conf ]; then
    sudo cp /etc/xbps.d/00-repository-main.conf "$BACKUP_DIR/"
fi

# Configurar repositorios oficiales incluyendo multilib, nonfree
log_info "Configurando repositorios oficiales..."
sudo mkdir -p /etc/xbps.d/

# Repositorio principal
echo 'repository=https://repo-default.voidlinux.org/current' | sudo tee /etc/xbps.d/00-repository-main.conf > /dev/null

# Repositorio multilib (32-bit)
echo 'repository=https://repo-default.voidlinux.org/current/multilib' | sudo tee /etc/xbps.d/10-repository-multilib.conf > /dev/null

# Repositorio nonfree
echo 'repository=https://repo-default.voidlinux.org/current/nonfree' | sudo tee /etc/xbps.d/20-repository-nonfree.conf > /dev/null

# Repositorio multilib-nonfree
echo 'repository=https://repo-default.voidlinux.org/current/multilib/nonfree' | sudo tee /etc/xbps.d/30-repository-multilib-nonfree.conf > /dev/null

log_success "Repositorios configurados: main, multilib, nonfree, multilib-nonfree"

# Actualizar repositorios
log_info "Actualizando repositorios..."
if sudo xbps-install -S; then
    log_success "Repositorios sincronizados"
else
    log_error "Error al sincronizar repositorios"
    exit 1
fi

# =============================================
# FASE 2: ACTUALIZACIÓN DEL SISTEMA
# =============================================

log_step "ACTUALIZACIÓN DEL SISTEMA"

log_info "Actualizando sistema completo..."
if sudo xbps-install -u; then
    log_success "Sistema actualizado"
    NEEDS_REBOOT=true
else
    log_warning "Posibles errores en la actualización, continuando..."
fi

# =============================================
# FASE 3: INSTALACIÓN DE PAQUETES BASE
# =============================================

log_step "INSTALACIÓN DE PAQUETES BASE"

# Función para instalar paquetes con verificación mejorada
install_packages() {
    local package_array=("$@")
    local packages_to_install=()
    local failed_packages=()

    for package in "${package_array[@]}"; do
        if ! xbps-query -l "$package" &>/dev/null; then
            packages_to_install+=("$package")
        else
            log_success "$package ya instalado"
        fi
    done

    if [ ${#packages_to_install[@]} -gt 0 ]; then
        log_info "Instalando: ${packages_to_install[*]}"
        for package in "${packages_to_install[@]}"; do
            if sudo xbps-install -y "$package"; then
                log_success "$package instalado"
            else
                failed_packages+=("$package")
                log_warning "Fallo al instalar $package"
            fi
        done
        
        if [ ${#failed_packages[@]} -gt 0 ]; then
            log_warning "Paquetes fallidos: ${failed_packages[*]}"
        fi
        
        NEEDS_REBOOT=true
    else
        log_success "Todos los paquetes ya están instalados"
    fi
}

# Paquetes base del sistema
BASE_PACKAGES=(
    "xorg-minimal"
    "xorg-server"
    "xorg-input-drivers"
    "xfce4"
    "lightdm"
    "lightdm-gtk3-greeter"
    "dbus"
    "elogind"
    "NetworkManager"
)

log_optimization "Instalando paquetes base del sistema"
install_packages "${BASE_PACKAGES[@]}"

# =============================================
# FASE 4: DRIVERS GRÁFICOS ESPECÍFICOS KAVERI
# =============================================

log_step "DRIVERS GRÁFICOS AMD KAVERI (A8-7600B)"

# IMPORTANTE: Para Kaveri (A8-7600B), usar SOLO xf86-video-ati/radeon
# NO usar amdgpu que puede causar pantalla negra

# Desinstalar drivers conflictivos si existen
CONFLICTING_DRIVERS=(
    "xf86-video-amdgpu"
    "amdgpu-firmware" 
)

log_info "Removiendo drivers conflictivos para Kaveri..."
for driver in "${CONFLICTING_DRIVERS[@]}"; do
    if xbps-query -l "$driver" &>/dev/null; then
        sudo xbps-remove -y "$driver"
        log_success "Removido driver conflictivo: $driver"
        NEEDS_REBOOT=true
    fi
done

# Drivers correctos para AMD Kaveri A8-7600B
KAVERI_GRAPHICS_PACKAGES=(
    "mesa"
    "mesa-dri"
    "xf86-video-ati"
    "mesa-vulkan-radeon"
    "mesa-vaapi"
    "mesa-vdpau"
    "libdrm"
    "libglvnd"
)

log_optimization "Instalando drivers específicos para Kaveri"
install_packages "${KAVERI_GRAPHICS_PACKAGES[@]}"

# Soporte 32-bit para gráficos
GRAPHICS_32BIT_PACKAGES=(
    "mesa-32bit"
    "libdrm-32bit"
    "libglvnd-32bit"
    "libva-32bit"
    "libvdpau-32bit"
    "vulkan-loader-32bit"
)

log_optimization "Instalando soporte gráfico 32-bit"
install_packages "${GRAPHICS_32BIT_PACKAGES[@]}"

# =============================================
# FASE 5: CONFIGURACIÓN XORG SEGURA
# =============================================

log_step "CONFIGURACIÓN XORG PARA KAVERI"

# Backup configuración existente
if [ -d /etc/X11/xorg.conf.d/ ]; then
    sudo cp -r /etc/X11/xorg.conf.d/ "$BACKUP_DIR/" 2>/dev/null
fi

sudo mkdir -p /etc/X11/xorg.conf.d/

# Configuración minimalista y segura para Kaveri
log_optimization "Creando configuración Xorg segura para Kaveri"
sudo tee /etc/X11/xorg.conf.d/20-amd-kaveri.conf > /dev/null <<'EOF'
Section "Device"
    Identifier "AMD Kaveri Graphics"
    Driver "radeon"
    Option "TearFree" "true"
    Option "DRI" "3"
    # Configuración conservadora para evitar pantalla negra
    Option "AccelMethod" "glamor"
    Option "ColorTiling" "on"
EndSection
EOF

log_success "Configuración Xorg para Kaveri creada (conservadora)"

# =============================================
# FASE 6: ZRAMEN PARA OPTIMIZACIÓN DE MEMORIA
# =============================================

log_step "CONFIGURACIÓN DE ZRAMEN"

# Instalar zramen específicamente
log_optimization "Instalando zramen"
if sudo xbps-install -y zramen; then
    log_success "zramen instalado"
    
    # Configurar zramen para 14GB RAM
    sudo mkdir -p /etc/default
    sudo tee /etc/default/zramen > /dev/null <<'EOF'
# Configuración zramen para AMD A8-7600B con 14GB RAM
# Usar 25% de RAM para zramen (aproximadamente 3.5GB)
ZRAM_SIZE="3584M"
ZRAM_STREAMS="4"
ZRAM_COMP_ALGORITHM="lz4"
EOF
    
    # Habilitar servicio zramen
    if [ -d "/etc/sv/zramen" ]; then
        sudo ln -sf /etc/sv/zramen /var/service/
        log_success "Servicio zramen habilitado"
        NEEDS_REBOOT=true
    else
        log_warning "Servicio zramen no encontrado en /etc/sv/"
    fi
    
    log_success "zramen configurado para 14GB RAM"
else
    log_error "Error al instalar zramen"
fi

# =============================================
# FASE 7: OPTIMIZACIONES DE SISTEMA
# =============================================

log_step "OPTIMIZACIONES DEL SISTEMA"

# Parámetros sysctl optimizados
sudo mkdir -p /etc/sysctl.d/
sudo tee /etc/sysctl.d/99-amd-optimization.conf > /dev/null <<'EOF'
# Optimizaciones para AMD A8-7600B con 14GB RAM y SSD

# Memoria virtual - swappiness bajo para SSD
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_background_ratio=5
vm.dirty_ratio=10

# Memoria compartida para APU
kernel.shmmax=8589934592
kernel.shmall=2097152

# Red
net.core.rmem_default=262144
net.core.rmem_max=16777216
net.core.wmem_default=262144
net.core.wmem_max=16777216

# Filesystem
fs.file-max=2097152
EOF

log_success "Parámetros sysctl configurados"

# Aplicar cambios sysctl
sudo sysctl -p /etc/sysctl.d/99-amd-optimization.conf &>/dev/null

# =============================================
# FASE 8: OPTIMIZACIONES SSD
# =============================================

log_step "OPTIMIZACIONES SSD"

# Detectar SSD
SSD_DEVICE=""
NVME_DEVICE=$(lsblk -d -o NAME,ROTA | awk '$2 == "0" && $1 ~ /^nvme/ {print $1}' | head -1)
if [ -n "$NVME_DEVICE" ]; then
    SSD_DEVICE="$NVME_DEVICE"
else
    SD_SSD_DEVICE=$(lsblk -d -o NAME,ROTA | awk '$2 == "0" && $1 ~ /^sd/ {print $1}' | head -1)
    if [ -n "$SD_SSD_DEVICE" ]; then
        SSD_DEVICE="$SD_SSD_DEVICE"
    fi
fi

if [ -n "$SSD_DEVICE" ]; then
    log_info "SSD detectado: /dev/$SSD_DEVICE"
    
    # Configurar scheduler
    sudo mkdir -p /etc/udev/rules.d/
    echo "ACTION==\"add|change\", KERNEL==\"$SSD_DEVICE\", ATTR{queue/scheduler}=\"mq-deadline\"" | \
        sudo tee /etc/udev/rules.d/60-ssd-scheduler.conf > /dev/null
    
    # TRIM automático
    sudo mkdir -p /etc/cron.weekly/
    sudo tee /etc/cron.weekly/fstrim > /dev/null <<'EOF'
#!/bin/sh
/usr/bin/fstrim -av
EOF
    sudo chmod +x /etc/cron.weekly/fstrim
    
    log_success "Optimizaciones SSD aplicadas"
else
    log_warning "No se detectó SSD"
fi

# =============================================
# FASE 9: INSTALACIÓN Y CONFIGURACIÓN ZSH
# =============================================

log_step "INSTALACIÓN Y CONFIGURACIÓN ZSH"

# Instalar zsh y dependencias
ZSH_PACKAGES=(
    "zsh"
    "git"
    "curl"
    "wget"
    "exa"
    "bat"
    "fd"
    "ripgrep"
    "fzf"
    "neofetch"
)

log_optimization "Instalando zsh y herramientas modernas"
install_packages "${ZSH_PACKAGES[@]}"

# Instalar Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log_optimization "Instalando Oh My Zsh"
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    log_success "Oh My Zsh instalado"
fi

# Instalar Powerlevel10k theme
if [ ! -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
    log_optimization "Instalando tema Powerlevel10k"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k
    log_success "Powerlevel10k instalado"
fi

# Instalar plugins útiles
log_optimization "Instalando plugins de zsh"

# zsh-autosuggestions
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
fi

# zsh-syntax-highlighting
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
fi

# zsh-completions
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-completions" ]; then
    git clone https://github.com/zsh-users/zsh-completions ~/.oh-my-zsh/custom/plugins/zsh-completions
fi

log_success "Plugins de zsh instalados"

# Configurar .zshrc
log_optimization "Configurando .zshrc"
cp ~/.zshrc ~/.zshrc.backup 2>/dev/null || true

cat > ~/.zshrc <<'EOF'
# Configuración ZSH optimizada para AMD A8-7600B
export ZSH="$HOME/.oh-my-zsh"

# Tema Powerlevel10k
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
plugins=(
    git
    sudo
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
    colored-man-pages
    command-not-found
    history-substring-search
    fzf
)

source $ZSH/oh-my-zsh.sh

# Aliases modernos
alias ls='exa --icons --group-directories-first'
alias ll='exa -la --icons --group-directories-first'
alias lt='exa --tree --icons'
alias cat='bat --paging=never'
alias find='fd'
alias grep='rg'
alias top='htop'
alias df='df -h'
alias du='du -h'
alias free='free -h'

# Aliases específicos del sistema
alias temp='sensors | grep -E "(temp|Core)"'
alias gpu-info='lspci | grep -i vga'
alias sysinfo='neofetch'

# Variables de entorno
export EDITOR='nano'
export BROWSER='firefox'
export TERM='xterm-256color'

# Historial mejorado
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE

# FZF configuración
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

# Autocompletado mejorado
autoload -U compinit && compinit
EOF

log_success "Configuración .zshrc creada"

# Cambiar shell por defecto a zsh
if [ "$SHELL" != "/bin/zsh" ] && [ "$SHELL" != "/usr/bin/zsh" ]; then
    log_optimization "Cambiando shell por defecto a zsh"
    chsh -s /bin/zsh
    log_success "Shell cambiado a zsh (requiere nueva sesión)"
fi

# =============================================
# FASE 10: PAQUETES MULTIMEDIA Y UTILIDADES
# =============================================

log_step "PAQUETES MULTIMEDIA Y UTILIDADES"

# Multimedia
MULTIMEDIA_PACKAGES=(
    
    "alsa-utils"
    "gstreamer1-vaapi"
    "ffmpeg"
    "firefox"
)

log_optimization "Instalando paquetes multimedia"
install_packages "${MULTIMEDIA_PACKAGES[@]}"

# Soporte 32-bit adicional
SUPPORT_32BIT_PACKAGES=(
    "alsa-lib-32bit"
    "libgcc-32bit"
    "libstdc++-32bit"
    "glibc-32bit"
    
)

log_optimization "Instalando soporte 32-bit adicional"
install_packages "${SUPPORT_32BIT_PACKAGES[@]}"

# Herramientas del sistema
SYSTEM_TOOLS=(
    "htop"
    "lm_sensors"
    "smartmontools"
    "util-linux"
    "tree"
    "unzip"
    "zip"
)

log_optimization "Instalando herramientas del sistema"
install_packages "${SYSTEM_TOOLS[@]}"

# =============================================
# FASE 11: CONFIGURACIÓN DE SERVICIOS
# =============================================

log_step "CONFIGURACIÓN DE SERVICIOS"

# Servicios esenciales
ESSENTIAL_SERVICES=(
    "lightdm"
    "dbus"
    "elogind"
    "NetworkManager"
)

log_optimization "Habilitando servicios esenciales"
for service in "${ESSENTIAL_SERVICES[@]}"; do
    if [ -d "/etc/sv/$service" ]; then
        if ! [ -L "/var/service/$service" ]; then
            sudo ln -sf "/etc/sv/$service" /var/service/
            log_success "Servicio $service habilitado"
            NEEDS_REBOOT=true
        else
            log_success "Servicio $service ya habilitado"
        fi
    else
        log_warning "Servicio $service no encontrado"
    fi
done

# Configurar lightdm
if [ -f /etc/lightdm/lightdm.conf ]; then
    sudo cp /etc/lightdm/lightdm.conf "$BACKUP_DIR/"
    sudo sed -i 's/#greeter-session=.*/greeter-session=lightdm-gtk-greeter/' /etc/lightdm/lightdm.conf
    sudo sed -i 's/#user-session=.*/user-session=xfce/' /etc/lightdm/lightdm.conf
    log_success "Configuración lightdm optimizada"
fi

# =============================================
# FASE 12: CONFIGURACIÓN DE USUARIO
# =============================================

log_step "CONFIGURACIÓN DE USUARIO"

# Agregar usuario a grupos
USER_GROUPS="audio video input plugdev wheel optical storage"
GROUPS_ADDED=()

for group in $USER_GROUPS; do
    if ! groups "$USER_NAME" | grep -q "\b$group\b"; then
        if sudo usermod -aG "$group" "$USER_NAME"; then
            GROUPS_ADDED+=("$group")
            log_success "Usuario agregado al grupo: $group"
        fi
    else
        log_success "Usuario ya en el grupo: $group"
    fi
done

# =============================================
# FASE 13: VARIABLES DE ENTORNO AMD
# =============================================

log_step "VARIABLES DE ENTORNO AMD"

sudo mkdir -p /etc/profile.d/
sudo tee /etc/profile.d/amd-kaveri.sh > /dev/null <<'EOF'
# Variables de entorno para AMD Kaveri A8-7600B
export MESA_GL_VERSION_OVERRIDE="4.5"
export MESA_GLSL_VERSION_OVERRIDE="450"
export R600_DEBUG="hyperz"
export RADEON_HYPERZ="1"
export force_s3tc_enable="true"
export __GL_SHADER_DISK_CACHE="1"
export __GL_SHADER_DISK_CACHE_PATH="/tmp"
export MESA_DISK_CACHE_SIZE="1GB"
EOF

log_success "Variables de entorno AMD configuradas"

# =============================================
# FASE 14: SCRIPTS DE MONITOREO
# =============================================

log_step "CREANDO SCRIPTS DE MONITOREO"

# Script de información del sistema
sudo tee /usr/local/bin/sysinfo-amd > /dev/null <<'EOF'
#!/bin/bash
echo "=== INFORMACIÓN SISTEMA AMD A8-7600B ==="
echo "Fecha: $(date)"
echo ""

echo "CPU Info:"
lscpu | grep -E "(Model name|CPU MHz|Cache)"
echo ""

echo "GPU Info:"
lspci | grep -i vga
echo ""

echo "Memoria:"
free -h
echo ""

if command -v sensors >/dev/null 2>&1; then
    echo "Temperaturas:"
    sensors | grep -E "(temp|Core|fan)" || echo "Sensores no configurados"
else
    echo "lm_sensors no instalado"
fi
echo ""

echo "Zramen status:"
if systemctl is-active --quiet zramen 2>/dev/null || sv status zramen 2>/dev/null; then
    echo "✓ Zramen activo"
else
    echo "⚠ Zramen no activo"
fi
EOF

sudo chmod +x /usr/local/bin/sysinfo-amd
log_success "Script sysinfo-amd creado"

# =============================================
# VERIFICACIÓN FINAL
# =============================================

log_step "VERIFICACIÓN FINAL"

# Detectar sensores
if command -v sensors-detect >/dev/null 2>&1; then
    log_info "Configurando sensores de temperatura..."
    echo "YES" | sudo sensors-detect --auto &>/dev/null || true
fi

echo ""
echo "================================================================"
log_step "OPTIMIZACIÓN COMPLETADA - AMD A8-7600B KAVERI"
echo "================================================================"

echo ""
log_optimization "CARACTERÍSTICAS INSTALADAS:"
echo "✅ Drivers Radeon específicos para Kaveri (evita pantalla negra)"
echo "✅ Repositorios: main, multilib, nonfree configurados"
echo "✅ Zramen configurado para 14GB RAM"
echo "✅ Soporte completo 32-bit"
echo "✅ ZSH con Oh My Zsh y Powerlevel10k"
echo "✅ SSD optimizado"
echo "✅ Variables AMD configuradas"

echo ""
log_info "COMANDOS NUEVOS DISPONIBLES:"
echo "📊 sysinfo-amd     - Información completa del sistema"
echo "💻 neofetch        - Información visual del sistema"
echo "📈 htop            - Monitor de procesos mejorado"
echo "🎨 Nuevos aliases en zsh (ls, ll, cat, etc.)"

echo ""
if [ ${#GROUPS_ADDED[@]} -gt 0 ]; then
    log_warning "GRUPOS AGREGADOS: ${GROUPS_ADDED[*]}"
    echo "⚠️  CIERRA SESIÓN Y VUELVE A ENTRAR para aplicar cambios de grupo."
    NEEDS_REBOOT=true
fi

if [ "$NEEDS_REBOOT" = true ]; then
    echo ""
    log_warning "REINICIO RECOMENDADO"
    echo "🔄 Para aplicar todas las optimizaciones:"
    echo "   sudo reboot"
    echo ""
    echo "🎯 Después del reinicio:"
    echo "   - Inicia sesión y abre una terminal"
    echo "   - Tu shell será ZSH con tema moderno"
    echo "   - Ejecuta: sysinfo-amd para verificar"
    echo "   - Si es la primera vez con zsh, configura Powerlevel10k"
else 
    echo ""
    log_success "OPTIMIZACIONES APLICADAS"
    echo "✨ Abre una nueva terminal para usar ZSH"
fi

echo ""
echo "📁 BACKUP EN: $BACKUP_DIR"
echo "🔧 CONFIGURACIONES EN: /etc/X11/xorg.conf.d/, /etc/sysctl.d/"

echo ""
echo "================================================================"
log_warning "IMPORTANTE: Esta configuración es específica para Kaveri"
log_warning "No uses drivers amdgpu - causarán pantalla negra"
echo "================================================================"
echo ""
echo "🎮 DISFRUTA TU VOID LINUX OPTIMIZADO 🎮"