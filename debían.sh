#!/bin/bash

# --- Verificación root ---
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Ejecuta como root o con sudo." >&2
    exit 1
fi

# --- Detección de distribución ---
if grep -q "Debian" /etc/os-release; then
    DISTRO="debian"
elif grep -q "Ubuntu" /etc/os-release; then
    DISTRO="ubuntu"
elif grep -q "Arch" /etc/os-release; then
    DISTRO="arch"
else
    echo "ERROR: Distro no soportada." >&2
    exit 1
fi

# --- Detección de GPU (Kaveri) ---
GPU_INFO=$(lspci -nn | grep -i "VGA.*AMD")
if [[ $GPU_INFO != *"Kaveri"* ]]; then
    echo "WARNING: GPU no detectada como Kaveri. Forzando configuración igualmente."
fi

# --- Función para configurar amdgpu ---
configure_amdgpu() {
    echo "[+] Configurando AMDGPU (moderno)..."
    
    # Instalar paquetes
    if [ "$DISTRO" = "debian" ] || [ "$DISTRO" = "ubuntu" ]; then
        apt install -y firmware-amd-graphics xserver-xorg-video-amdgpu mesa-vulkan-drivers libdrm-amdgpu1
    elif [ "$DISTRO" = "arch" ]; then
        pacman -S --noconfirm mesa vulkan-radeon xf86-video-amdgpu
    fi

    # Forzar amdgpu en kernel
    if [ -f /etc/default/grub ]; then
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/&radeon.si_support=0 amdgpu.si_support=1 /' /etc/default/grub
        update-grub 2>/dev/null || grub-mkconfig -o /boot/grub/grub.cfg
    fi

    # Configurar Xorg
    mkdir -p /etc/X11/xorg.conf.d
    cat > /etc/X11/xorg.conf.d/20-amdgpu.conf <<EOF
Section "Device"
    Identifier "AMD"
    Driver "amdgpu"
    Option "TearFree" "true"
    Option "DRI" "3"
    Option "AccelMethod" "glamor"
EndSection
EOF

    echo "[+] AMDGPU configurado. Reinicia para aplicar."
}

# --- Función para configurar radeon (fallback) ---
configure_radeon() {
    echo "[+] Configurando Radeon (legacy)..."
    
    if [ "$DISTRO" = "debian" ] || [ "$DISTRO" = "ubuntu" ]; then
        apt install -y xserver-xorg-video-ati
    elif [ "$DISTRO" = "arch" ]; then
        pacman -S --noconfirm xf86-video-ati
    fi

    # Configurar Xorg para radeon
    mkdir -p /etc/X11/xorg.conf.d
    cat > /etc/X11/xorg.conf.d/10-radeon.conf <<EOF
Section "Device"
    Identifier "AMD"
    Driver "radeon"
    Option "AccelMethod" "exa"
    Option "DRI" "3"
    Option "TearFree" "on"
EndSection
EOF

    echo "[+] Radeon configurado. Reinicia para aplicar."
}

# --- Ejecutar autodetección y configuración ---
KERNEL_VERSION=$(uname -r)
if [[ "$KERNEL_VERSION" =~ "5.4" || "$KERNEL_VERSION" =~ "5.10" ]] && [ "$DISTRO" != "arch" ]; then
    # Kernel LTS detectado: Intentar amdgpu primero
    configure_amdgpu
else
    # Kernel no-LTS o Arch: Usar radeon para mayor estabilidad
    echo "[!] Kernel detectado: $KERNEL_VERSION. Usando Radeon por compatibilidad."
    configure_radeon
fi

# --- Regenerar initramfs ---
if [ "$DISTRO" = "debian" ] || [ "$DISTRO" = "ubuntu" ]; then
    update-initramfs -u
elif [ "$DISTRO" = "arch" ]; then
    mkinitcpio -P
fi

echo "[+] Proceso completado. Reinicia el sistema."