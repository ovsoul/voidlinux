#!/bin/bash

# Script de diagnóstico y reparación para shell de emergencia en Void Linux
# Ejecutar desde shell de emergencia o live USB

echo "=== DIAGNÓSTICO Y REPARACIÓN VOID LINUX ==="
echo "Shell de emergencia - Análisis del sistema"
echo "==========================================="

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# PASO 1: Diagnóstico inicial
print_status "=== PASO 1: DIAGNÓSTICO INICIAL ==="

# Verificar sistema de archivos
print_status "Verificando sistemas de archivos..."
lsblk
echo ""
df -h
echo ""

# Verificar errores en fstab
print_status "Verificando /etc/fstab..."
if [[ -f /etc/fstab ]]; then
    cat /etc/fstab
    echo ""
    
    # Verificar sintaxis de fstab
    if mount -a --fake; then
        print_success "Sintaxis de fstab correcta"
    else
        print_error "Error en /etc/fstab - Necesita corrección"
    fi
else
    print_error "/etc/fstab no encontrado"
fi

# Verificar servicios críticos
print_status "Verificando servicios críticos..."
if [[ -d /var/service ]]; then
    ls -la /var/service/
    echo ""
else
    print_error "Directorio /var/service no encontrado"
fi

# Verificar logs del sistema
print_status "Verificando logs recientes..."
if command -v journalctl &> /dev/null; then
    journalctl -b -p err --no-pager | tail -20
else
    # Si no hay systemd, revisar dmesg
    dmesg | tail -20
fi

# PASO 2: Reparaciones automáticas
print_status "=== PASO 2: REPARACIONES AUTOMÁTICAS ==="

# Función para reparar fstab
repair_fstab() {
    print_status "Reparando /etc/fstab..."
    
    # Backup del fstab original
    cp /etc/fstab /etc/fstab.backup.$(date +%s)
    
    # Remover opciones problemáticas y crear fstab básico
    cat > /etc/fstab << 'EOF'
# <file system> <mount point> <type> <options> <dump> <pass>
# Configuración básica - editar según tu sistema
tmpfs /tmp tmpfs defaults,nosuid,nodev 0 0
EOF
    
    # Detectar particiones automáticamente
    print_status "Detectando particiones del sistema..."
    
    # Buscar partición root
    ROOT_PART=$(findmnt -n -o SOURCE /)
    if [[ -n "$ROOT_PART" ]]; then
        ROOT_UUID=$(blkid -s UUID -o value $ROOT_PART)
        if [[ -n "$ROOT_UUID" ]]; then
            echo "UUID=$ROOT_UUID / $(findmnt -n -o FSTYPE /) defaults 0 1" >> /etc/fstab
            print_success "Partición root agregada: $ROOT_PART"
        fi
    fi
    
    # Buscar partición boot si existe
    if [[ -d /boot ]] && mountpoint -q /boot; then
        BOOT_PART=$(findmnt -n -o SOURCE /boot)
        if [[ -n "$BOOT_PART" ]]; then
            BOOT_UUID=$(blkid -s UUID -o value $BOOT_PART)
            if [[ -n "$BOOT_UUID" ]]; then
                echo "UUID=$BOOT_UUID /boot $(findmnt -n -o FSTYPE /boot) defaults 0 2" >> /etc/fstab
                print_success "Partición boot agregada: $BOOT_PART"
            fi
        fi
    fi
    
    print_status "Nuevo /etc/fstab:"
    cat /etc/fstab
}

# Función para reparar servicios
repair_services() {
    print_status "Reparando servicios básicos..."
    
    # Crear directorio de servicios si no existe
    mkdir -p /var/service
    
    # Servicios esenciales mínimos
    ESSENTIAL_SERVICES=(
        "agetty-tty1"
        "agetty-tty2" 
        "udevd"
    )
    
    for service in "${ESSENTIAL_SERVICES[@]}"; do
        if [[ -d "/etc/sv/$service" ]]; then
            if [[ ! -L "/var/service/$service" ]]; then
                ln -sf "/etc/sv/$service" "/var/service/"
                print_success "Servicio $service habilitado"
            fi
        fi
    done
    
    # Remover servicios problemáticos temporalmente
    PROBLEMATIC_SERVICES=(
        "sddm"
        "NetworkManager"
        "bluetoothd"
    )
    
    for service in "${PROBLEMATIC_SERVICES[@]}"; do
        if [[ -L "/var/service/$service" ]]; then
            rm -f "/var/service/$service"
            print_warning "Servicio $service deshabilitado temporalmente"
        fi
    done
}

# Función para verificar y reparar GRUB
repair_grub() {
    print_status "Verificando configuración de GRUB..."
    
    if [[ -f /etc/default/grub ]]; then
        print_status "Contenido actual de /etc/default/grub:"
        cat /etc/default/grub
        echo ""
        
        # Crear backup
        cp /etc/default/grub /etc/default/grub.backup.$(date +%s)
        
        # Limpiar parámetros problemáticos
        sed -i 's/radeon\.dpm=1//g' /etc/default/grub
        sed -i 's/radeon\.audio=1//g' /etc/default/grub
        sed -i 's/amdgpu\.dpm=1//g' /etc/default/grub
        
        # Regenerar configuración de GRUB
        if command -v grub-mkconfig &> /dev/null; then
            grub-mkconfig -o /boot/grub/grub.cfg
            print_success "Configuración de GRUB regenerada"
        else
            print_warning "grub-mkconfig no disponible"
        fi
    fi
}

# Función principal de reparación
main_repair() {
    print_status "Iniciando reparaciones..."
    
    # Montar sistema de archivos en modo lectura-escritura
    mount -o remount,rw /
    
    # Reparar fstab si hay problemas
    if ! mount -a --fake &>/dev/null; then
        print_warning "Problemas detectados en fstab, reparando..."
        repair_fstab
    fi
    
    # Reparar servicios
    repair_services
    
    # Reparar GRUB
    repair_grub
    
    # Verificar y reparar paquetes críticos
    print_status "Verificando paquetes críticos..."
    
    # Verificar si xbps está funcionando
    if command -v xbps-query &> /dev/null; then
        # Verificar paquetes esenciales
        CRITICAL_PACKAGES=("base-system" "runit" "void-release")
        
        for pkg in "${CRITICAL_PACKAGES[@]}"; do
            if ! xbps-query -l | grep -q "$pkg"; then
                print_error "Paquete crítico $pkg no encontrado"
                print_status "Intentando reinstalar $pkg..."
                xbps-install -f "$pkg"
            else
                print_success "Paquete $pkg OK"
            fi
        done
    fi
    
    print_success "Reparaciones completadas"
}

# PASO 3: Modo seguro
create_safe_boot() {
    print_status "=== PASO 3: CONFIGURACIÓN MODO SEGURO ==="
    
    # Crear configuración mínima para arranque seguro
    cat > /etc/rc.local << 'EOF'
#!/bin/sh
# Configuración de arranque seguro

# Montar sistemas de archivos básicos
mount -a

# Iniciar servicios mínimos
sv start udevd

echo "Sistema iniciado en modo seguro"
echo "Para diagnóstico adicional, ejecute: /usr/local/bin/void-repair"
EOF
    
    chmod +x /etc/rc.local
    
    print_success "Modo seguro configurado"
}

# PASO 4: Script de diagnóstico permanente
create_diagnostic_script() {
    print_status "Creando script de diagnóstico permanente..."
    
    cat > /usr/local/bin/void-repair << 'SCRIPT_EOF'
#!/bin/bash
# Script de diagnóstico permanente para Void Linux

echo "=== DIAGNÓSTICO VOID LINUX ==="

echo "1. Estado de servicios:"
sv status /var/service/*

echo -e "\n2. Montajes:"
mount | grep -v tmpfs

echo -e "\n3. Espacio en disco:"
df -h

echo -e "\n4. Errores recientes:"
dmesg | grep -i error | tail -10

echo -e "\n5. Paquetes rotos:"
xbps-query -L 2>/dev/null || echo "xbps no disponible"

echo -e "\n6. Red:"
ip addr show

echo -e "\nPara reparaciones:"
echo "- Reinstalar sistema base: xbps-install -f base-system"
echo "- Reconfigurar servicios: rm /var/service/* && sv-enable basic-services"
echo "- Verificar fstab: mount -a --fake"
SCRIPT_EOF
    
    chmod +x /usr/local/bin/void-repair
    print_success "Script de diagnóstico creado en /usr/local/bin/void-repair"
}

# Menú principal
show_menu() {
    echo ""
    echo "=== MENÚ DE REPARACIÓN ==="
    echo "1. Diagnóstico completo"
    echo "2. Reparación automática"
    echo "3. Configurar modo seguro"
    echo "4. Crear script de diagnóstico"
    echo "5. Reparación manual guiada"
    echo "6. Salir"
    echo ""
    read -p "Selecciona una opción (1-6): " choice
    
    case $choice in
        1)
            print_status "Ejecutando diagnóstico completo..."
            # El diagnóstico ya se ejecutó al inicio
            ;;
        2)
            main_repair
            ;;
        3)
            create_safe_boot
            ;;
        4)
            create_diagnostic_script
            ;;
        5)
            manual_repair_guide
            ;;
        6)
            print_status "Saliendo..."
            exit 0
            ;;
        *)
            print_error "Opción inválida"
            show_menu
            ;;
    esac
}

# Guía de reparación manual
manual_repair_guide() {
    print_status "=== GUÍA DE REPARACIÓN MANUAL ==="
    echo ""
    echo "COMANDOS ÚTILES PARA REPARACIÓN MANUAL:"
    echo ""
    echo "1. Verificar sistema de archivos:"
    echo "   fsck /dev/sdaX  (reemplaza X con tu partición)"
    echo ""
    echo "2. Montar en modo lectura-escritura:"
    echo "   mount -o remount,rw /"
    echo ""
    echo "3. Rehabilitar servicios básicos:"
    echo "   rm /var/service/*"
    echo "   ln -sf /etc/sv/agetty-tty1 /var/service/"
    echo "   ln -sf /etc/sv/udevd /var/service/"
    echo ""
    echo "4. Reinstalar paquetes críticos:"
    echo "   xbps-install -f base-system runit"
    echo ""
    echo "5. Regenerar initramfs:"
    echo "   xbps-reconfigure -f linux"
    echo ""
    echo "6. Verificar y reparar GRUB:"
    echo "   grub-mkconfig -o /boot/grub/grub.cfg"
    echo ""
    echo "7. Reiniciar servicios:"
    echo "   sv restart udevd"
    echo ""
    
    read -p "Presiona Enter para continuar..."
}

# Ejecutar diagnóstico inicial automáticamente
main_repair

# Mostrar menú
show_menu