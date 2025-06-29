#!/bin/bash

# Script de instalación de Diablo 2: Lord of Destruction para Void Linux
# Autor: Asistente IA
# Fecha: $(date +%Y-%m-%d)

set -e  # Salir si hay errores

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir mensajes coloridos
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[ADVERTENCIA]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar si somos root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "No ejecutes este script como root. Se pedirá sudo cuando sea necesario."
        exit 1
    fi
}

# Verificar que estamos en Void Linux
check_void_linux() {
    if [ ! -f /etc/os-release ] || ! grep -q "void" /etc/os-release; then
        print_error "Este script está diseñado para Void Linux"
        exit 1
    fi
    print_success "Sistema Void Linux detectado"
}

# Actualizar repositorios
update_system() {
    print_status "Actualizando repositorios del sistema..."
    sudo xbps-install -S
    print_success "Repositorios actualizados"
}

# Instalar dependencias básicas
install_dependencies() {
    print_status "Instalando dependencias básicas..."
    
    local packages=(
        "wine"
        "wine-32bit"  # CRÍTICO: Diablo 2 necesita soporte 32-bit
        "winetricks"
        "mesa-dri"
        "mesa-dri-32bit"  # Mesa 32-bit para compatibilidad
        "vulkan-loader"
        "vulkan-loader-32bit"  # Vulkan 32-bit
        "mesa-vulkan-radeon"  # Para gráficos AMD
        "mesa-vulkan-radeon-32bit"  # Mesa Vulkan 32-bit
        "alsa-lib"
        "alsa-lib-32bit"  # Audio 32-bit
        "alsa-lib-devel"
        "pulseaudio"
        "pulseaudio-32bit"  # PulseAudio 32-bit
        "zenity"  # Para diálogos gráficos
        "cabextract"  # Para extraer archivos .cab
        "unzip"  # Para archivos zip
    )
    
    for package in "${packages[@]}"; do
        if ! xbps-query -l | grep -q "^ii $package"; then
            print_status "Instalando $package..."
            if sudo xbps-install -y "$package"; then
                print_success "$package instalado correctamente"
            else
                print_warning "No se pudo instalar $package (puede que no esté disponible)"
            fi
        else
            print_success "$package ya está instalado"
        fi
    done
}

# Configurar Wine
setup_wine() {
    print_status "Configurando Wine..."
    
    # Limpiar configuración anterior si existe
    if [ -d "$HOME/.wine" ]; then
        print_warning "Detectada configuración anterior de Wine. ¿Quieres crear una nueva?"
        read -p "¿Eliminar configuración anterior? (s/N): " reset_wine
        if [[ $reset_wine =~ ^[Ss]$ ]]; then
            print_status "Eliminando configuración anterior..."
            rm -rf "$HOME/.wine"
        fi
    fi
    
    # Crear WINEPREFIX de 32-bit (CRÍTICO para Diablo 2)
    print_status "Creando WINEPREFIX de 32-bit..."
    export WINEPREFIX="$HOME/.wine"
    export WINEARCH=win32
    
    # Inicializar Wine
    print_status "Inicializando Wine..."
    wineboot --init
    sleep 5
    
    # Verificar que se creó correctamente
    if [ ! -d "$HOME/.wine" ]; then
        print_error "Error al crear WINEPREFIX"
        exit 1
    fi
    
    # Configurar Wine para Windows 7
    print_status "Configurando Wine para Windows 7..."
    winetricks -q win7
    
    # Instalar componentes necesarios uno por uno
    print_status "Instalando Visual C++ Runtime..."
    winetricks -q vcrun2019 || print_warning "Error instalando vcrun2019, continuando..."
    
    print_status "Instalando DirectX 9..."
    winetricks -q d3dx9 || print_warning "Error instalando d3dx9, continuando..."
    
    print_status "Instalando fuentes del sistema..."
    winetricks -q corefonts || print_warning "Error instalando corefonts, continuando..."
    
    print_success "Wine configurado correctamente"
}

# Función para instalar Diablo 2
install_diablo2() {
    print_status "Preparando instalación de Diablo 2..."
    
    echo
    print_warning "OPCIONES DE INSTALACIÓN:"
    echo "1) Tengo los CDs/DVDs originales"
    echo "2) Tengo archivos de instalación descargados"
    echo "3) Tengo una imagen ISO"
    echo "4) Instalar solo el entorno (sin el juego)"
    echo
    read -p "Selecciona una opción (1-4): " option
    
    case $option in
        1)
            install_from_cd
            ;;
        2)
            install_from_files
            ;;
        3)
            install_from_iso
            ;;
        4)
            print_success "Entorno preparado. El juego se puede instalar manualmente más tarde."
            ;;
        *)
            print_error "Opción inválida"
            exit 1
            ;;
    esac
}

# Instalar desde CD/DVD
install_from_cd() {
    print_status "Buscando unidades de CD/DVD montadas..."
    
    cd_path=$(find /media /mnt -name "*.exe" -o -name "Setup.exe" -o -name "install.exe" 2>/dev/null | head -1)
    
    if [ -z "$cd_path" ]; then
        print_warning "No se encontró instalador automáticamente."
        read -p "Introduce la ruta completa al instalador (ej: /media/cdrom/Setup.exe): " cd_path
    fi
    
    if [ -f "$cd_path" ]; then
        print_status "Ejecutando instalador desde: $cd_path"
        wine "$cd_path"
    else
        print_error "No se pudo encontrar el archivo de instalación"
        exit 1
    fi
}

# Instalar desde archivos descargados
install_from_files() {
    read -p "Introduce la ruta completa al instalador: " installer_path
    
    if [ -f "$installer_path" ]; then
        print_status "Ejecutando instalador: $installer_path"
        wine "$installer_path"
    else
        print_error "Archivo no encontrado: $installer_path"
        exit 1
    fi
}

# Instalar desde ISO
install_from_iso() {
    read -p "Introduce la ruta completa al archivo ISO: " iso_path
    
    if [ ! -f "$iso_path" ]; then
        print_error "Archivo ISO no encontrado: $iso_path"
        exit 1
    fi
    
    # Crear punto de montaje temporal
    mount_point="/tmp/diablo2_iso"
    sudo mkdir -p "$mount_point"
    
    print_status "Montando ISO..."
    sudo mount -o loop "$iso_path" "$mount_point"
    
    # Buscar instalador
    installer=$(find "$mount_point" -name "*.exe" -o -name "Setup.exe" | head -1)
    
    if [ -f "$installer" ]; then
        print_status "Ejecutando instalador desde ISO..."
        wine "$installer"
    else
        print_error "No se encontró instalador en la ISO"
    fi
    
    # Limpiar
    print_status "Desmontando ISO..."
    sudo umount "$mount_point"
    sudo rmdir "$mount_point"
}

# Crear script de lanzamiento
create_launcher() {
    print_status "Creando launcher para Diablo 2..."
    
    # Buscar ejecutable de Diablo 2
    d2_exe=$(find "$HOME/.wine/drive_c" -name "Diablo*.exe" 2>/dev/null | grep -v unins | head -1)
    
    if [ -z "$d2_exe" ]; then
        print_warning "No se encontró el ejecutable de Diablo 2 automáticamente"
        print_status "Puedes crear el launcher manualmente más tarde"
        return
    fi
    
    # Crear script de lanzamiento
    launcher_script="$HOME/bin/diablo2"
    mkdir -p "$HOME/bin"
    
    cat > "$launcher_script" << 'EOF'
#!/bin/bash

# Launcher para Diablo 2: Lord of Destruction
# Configurar variables de entorno para mejor rendimiento

export WINEPREFIX="$HOME/.wine"
export WINEARCH=win32  # CRÍTICO: Forzar 32-bit
export WINEDEBUG=-all  # Deshabilitar debug para mejor rendimiento

# Detectar ruta del juego
D2_PATH=$(find "$HOME/.wine/drive_c" -name "Diablo*.exe" 2>/dev/null | grep -v unins | head -1)

if [ -z "$D2_PATH" ]; then
    echo "Error: No se pudo encontrar Diablo 2"
    echo "Instala el juego primero o verifica la instalación"
    exit 1
fi

echo "Iniciando Diablo 2: Lord of Destruction..."
echo "Ruta del juego: $D2_PATH"

# Cambiar al directorio del juego
cd "$(dirname "$D2_PATH")"

# Ejecutar el juego
wine "$D2_PATH" "$@"
EOF

    chmod +x "$launcher_script"
    print_success "Launcher creado en: $launcher_script"
}

# Crear entrada de escritorio
create_desktop_entry() {
    print_status "Creando entrada de escritorio..."
    
    desktop_file="$HOME/.local/share/applications/diablo2.desktop"
    mkdir -p "$HOME/.local/share/applications"
    
    cat > "$desktop_file" << EOF
[Desktop Entry]
Name=Diablo 2: Lord of Destruction
Comment=Diablo 2: Lord of Destruction via Wine
Exec=$HOME/bin/diablo2
Icon=wine
Terminal=false
Type=Application
Categories=Game;
EOF

    print_success "Entrada de escritorio creada"
}

# Optimizaciones para AMD
optimize_for_amd() {
    print_status "Aplicando optimizaciones para gráficos AMD..."
    
    # Crear archivo de configuración de Wine
    wine_cfg="$HOME/.wine/user.reg"
    
    if [ -f "$wine_cfg" ]; then
        # Backup del archivo original
        cp "$wine_cfg" "$wine_cfg.backup"
        
        # Añadir configuraciones de DirectX
        print_status "Configurando DirectX para AMD..."
        winetricks -q d3dx9_43 d3dcompiler_43
    fi
    
    print_success "Optimizaciones AMD aplicadas"
}

# Mostrar información final
show_final_info() {
    echo
    print_success "¡Instalación completada!"
    echo
    print_status "INFORMACIÓN IMPORTANTE:"
    echo "• Launcher del juego: $HOME/bin/diablo2"
    echo "• También puedes buscar 'Diablo 2' en el menú de aplicaciones"
    echo "• Archivos de Wine en: $HOME/.wine"
    echo
    print_status "COMANDOS ÚTILES:"
    echo "• Ejecutar juego: ~/bin/diablo2"
    echo "• Configurar Wine: winecfg"
    echo "• Configurar audio: winecfg (pestaña Audio)"
    echo "• Desinstalar: wine uninstaller"
    echo
    print_status "CONSEJOS:"
    echo "• Si tienes problemas de colores, ejecuta el juego en modo ventana"
    echo "• Para mejor rendimiento, cierra otras aplicaciones"
    echo "• El juego se guarda en ~/.wine/drive_c/Program Files/Diablo II/"
    echo
    print_warning "Si encuentras problemas, verifica que los drivers de mesa estén actualizados"
}

# Función principal
main() {
    echo
    print_status "=== INSTALADOR DE DIABLO 2: LORD OF DESTRUCTION ==="
    print_status "=== PARA VOID LINUX CON GRÁFICOS AMD ==="
    echo
    
    check_root
    check_void_linux
    
    print_status "Iniciando instalación..."
    sleep 2
    
    update_system
    install_dependencies
    setup_wine
    optimize_for_amd
    install_diablo2
    create_launcher
    create_desktop_entry
    show_final_info
    
    print_success "¡Script completado exitosamente!"
}

# Ejecutar función principal
main "$@"