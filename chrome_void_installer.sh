#!/bin/bash

# Script de instalación y actualización de Google Chrome para Void Linux usando RPM
# Requiere permisos de root para instalar paquetes

set -e

CHROME_RPM_URL="https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm"
TEMP_DIR="/tmp/chrome-install"
CHROME_PACKAGE="google-chrome-stable"

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
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "No ejecutes este script como root. Se pedirán permisos sudo cuando sea necesario."
        exit 1
    fi
}

check_dependencies() {
    print_status "Verificando dependencias..."
    
    local deps=("curl" "wget")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    # Verificar rpmextract por separado
    if ! command -v "rpmextract" &> /dev/null; then
        missing_deps+=("rpmextract")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_warning "Instalando dependencias faltantes: ${missing_deps[*]}"
        sudo xbps-install -S "${missing_deps[@]}"
    fi
}

get_installed_version() {
    if command -v google-chrome &> /dev/null; then
        google-chrome --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+\.\d+' || echo "unknown"
    else
        echo "not_installed"
    fi
}

get_latest_version() {
    print_status "Obteniendo información de la última versión..."
    
    # Descargamos el RPM temporalmente para obtener la versión
    local temp_rpm="$TEMP_DIR/chrome-temp.rpm"
    mkdir -p "$TEMP_DIR"
    
    # Descargamos solo para verificar versión
    wget -q "$CHROME_RPM_URL" -O "$temp_rpm"
    
    # Usamos rpm2cpio para extraer info (si está disponible) o parseamos el nombre
    local version
    if command -v rpm &> /dev/null; then
        version=$(rpm -qp --queryformat '%{VERSION}' "$temp_rpm" 2>/dev/null || echo "")
    fi
    
    # Si no tenemos rpm, extraemos del nombre del archivo
    if [[ -z "$version" ]]; then
        # Método alternativo: descargar y usar rpmextract para ver archivos
        cd "$TEMP_DIR"
        rpmextract "$temp_rpm" > /dev/null 2>&1
        if [[ -f opt/google/chrome/chrome ]]; then
            version=$(strings opt/google/chrome/chrome | grep -oP '\d+\.\d+\.\d+\.\d+' | head -1 2>/dev/null || echo "")
        fi
        rm -rf opt usr etc 2>/dev/null || true
    fi
    
    echo "${version:-latest}"
}

download_and_extract_chrome() {
    print_status "Descargando Google Chrome RPM..."
    
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    local rpm_file="google-chrome-stable.rpm"
    wget "$CHROME_RPM_URL" -O "$rpm_file"
    
    print_status "Extrayendo paquete RPM..."
    
    # Extraer el paquete RPM usando rpmextract
    rpmextract "$rpm_file"
    
    if [[ ! -d opt/google ]]; then
        print_error "Error al extraer el paquete RPM"
        exit 1
    fi
}

install_runtime_dependencies() {
    print_status "Instalando dependencias de runtime..."
    
    local deps=(
        "alsa-lib"
        "gtk+3" 
        "libXrandr"
        "libXss"
        "libdrm"
        "libXcomposite"
        "libxkbcommon"
        "libXdamage"
        "libXtst"
        "libxshmfence"
        "mesa-dri"
        "nss"
        "at-spi2-atk"
        "cups"
        "libXScrnSaver"
        "liberation-fonts-ttf"
    )
    
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! xbps-query -s "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_status "Instalando dependencias: ${missing_deps[*]}"
        sudo xbps-install -y "${missing_deps[@]}" 2>/dev/null || {
            print_warning "Algunas dependencias no se pudieron instalar automáticamente"
            print_warning "Puedes instalarlas manualmente si Chrome no funciona correctamente"
        }
    fi
}

install_chrome() {
    print_status "Instalando Google Chrome..."
    
    # Copiar archivos binarios
    if [[ -d opt/google ]]; then
        sudo cp -r opt/google /opt/
        sudo chmod -R 755 /opt/google
    fi
    
    # Copiar archivos de sistema
    if [[ -d usr ]]; then
        sudo cp -r usr/* /usr/
    fi
    
    # Copiar archivos de configuración
    if [[ -d etc ]]; then
        sudo cp -r etc/* /etc/
    fi
    
    # Crear enlaces simbólicos si no existen
    if [[ ! -f /usr/bin/google-chrome ]]; then
        sudo ln -sf /opt/google/chrome/google-chrome /usr/bin/google-chrome
    fi
    
    if [[ ! -f /usr/bin/google-chrome-stable ]]; then
        sudo ln -sf /opt/google/chrome/google-chrome /usr/bin/google-chrome-stable
    fi
    
    # Establecer permisos correctos para el sandbox
    if [[ -f /opt/google/chrome/chrome-sandbox ]]; then
        sudo chown root:root /opt/google/chrome/chrome-sandbox
        sudo chmod 4755 /opt/google/chrome/chrome-sandbox
    fi
    
    # Crear archivo .desktop si no existe o está corrupto
    create_desktop_entry
    
    # Actualizar cache de aplicaciones
    update_system_caches
}

create_desktop_entry() {
    local desktop_file="/usr/share/applications/google-chrome.desktop"
    
    if [[ ! -f "$desktop_file" ]]; then
        print_status "Creando entrada de aplicación..."
        
        sudo tee "$desktop_file" > /dev/null << 'EOF'
[Desktop Entry]
Version=1.0
Name=Google Chrome
GenericName=Web Browser
GenericName[es]=Navegador web
Comment=Access the Internet
Comment[es]=Acceder a Internet
Exec=/opt/google/chrome/google-chrome %U
Terminal=false
Icon=google-chrome
Type=Application
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;application/xml;application/rss+xml;application/rdf+xml;image/gif;image/jpeg;image/png;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/ftp;x-scheme-handler/chrome;video/webm;application/x-xpinstall;
StartupNotify=true
StartupWMClass=Google-chrome
EOF
        
        sudo chmod 644 "$desktop_file"
        print_success "Archivo .desktop creado"
    else
        print_status "Archivo .desktop ya existe"
        
        # Verificar que el archivo .desktop apunta al ejecutable correcto
        if ! grep -q "/opt/google/chrome/google-chrome" "$desktop_file"; then
            print_warning "Corrigiendo ruta del ejecutable en .desktop"
            sudo sed -i 's|Exec=.*|Exec=/opt/google/chrome/google-chrome %U|' "$desktop_file"
        fi
    fi
}

update_system_caches() {
    print_status "Actualizando caches del sistema..."
    
    # Actualizar base de datos de aplicaciones
    if command -v update-desktop-database &> /dev/null; then
        sudo update-desktop-database 2>/dev/null || true
        print_status "Cache de aplicaciones actualizado"
    fi
    
    # Actualizar cache de iconos
    if command -v gtk-update-icon-cache &> /dev/null; then
        sudo gtk-update-icon-cache -f /usr/share/icons/hicolor/ 2>/dev/null || true
        print_status "Cache de iconos actualizado"
    fi
    
    # Actualizar cache de MIME types
    if command -v update-mime-database &> /dev/null; then
        sudo update-mime-database /usr/share/mime 2>/dev/null || true
        print_status "Cache de tipos MIME actualizado"
    fi
    
    # Forzar actualización del entorno de escritorio
    refresh_desktop_environment
}

refresh_desktop_environment() {
    print_status "Refrescando entorno de escritorio..."
    
    # Para diferentes entornos de escritorio
    if [[ -n "$XDG_CURRENT_DESKTOP" ]]; then
        case "$XDG_CURRENT_DESKTOP" in
            "XFCE")
                killall -USR1 xfce4-panel 2>/dev/null || true
                ;;
            "GNOME")
                # Recargar extensiones de GNOME Shell si está disponible
                gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method org.gnome.Shell.Eval 'Main.extensionManager.reloadExtensions()' 2>/dev/null || true
                ;;
            "KDE"|"plasma")
                # Actualizar cache de KDE
                kbuildsycoca5 2>/dev/null || kbuildsycoca4 2>/dev/null || true
                ;;
        esac
    fi
    
    # Método genérico para refrescar
    killall -HUP dbus-daemon 2>/dev/null || true
    
    print_warning "Nota: Si el icono no aparece inmediatamente:"
    print_warning "1. Cierra sesión y vuelve a entrar"
    print_warning "2. O reinicia tu entorno de escritorio"
    print_warning "3. O ejecuta 'hash -r' en la terminal"
}

cleanup() {
    print_status "Limpiando archivos temporales..."
    rm -rf "$TEMP_DIR"
}

verify_installation() {
    print_status "Verificando instalación..."
    
    if command -v google-chrome &> /dev/null; then
        local version=$(get_installed_version)
        print_success "Google Chrome $version instalado correctamente"
        
        # Verificar que los archivos principales existen
        if [[ -f /opt/google/chrome/chrome ]]; then
            print_success "Binario principal encontrado en /opt/google/chrome/chrome"
        fi
        
        local desktop_file="/usr/share/applications/google-chrome.desktop"
        if [[ -f "$desktop_file" ]]; then
            print_success "Entrada de menú de aplicaciones instalada"
            
            # Verificar que el archivo .desktop es válido
            if desktop-file-validate "$desktop_file" 2>/dev/null; then
                print_success "Archivo .desktop es válido"
            else
                print_warning "Archivo .desktop puede tener problemas menores"
            fi
        else
            print_warning "Archivo .desktop no encontrado, recreando..."
            create_desktop_entry
        fi
        
        # Verificar iconos
        if [[ -f /usr/share/icons/hicolor/*/apps/google-chrome.png ]] 2>/dev/null; then
            print_success "Iconos instalados correctamente"
        else
            print_warning "Algunos iconos pueden estar faltando"
        fi
        
        return 0
    else
        print_error "Error en la verificación de la instalación"
        return 1
    fi
}

show_post_install_info() {
    print_success "¡Instalación completada exitosamente!"
    echo
    print_status "Comandos disponibles:"
    echo "  - google-chrome"
    echo "  - google-chrome-stable"
    echo
    print_status "El icono debería aparecer en el menú de aplicaciones"
    echo
    
    # Mostrar información específica del entorno
    if [[ -n "$XDG_CURRENT_DESKTOP" ]]; then
        print_status "Entorno de escritorio detectado: $XDG_CURRENT_DESKTOP"
        
        case "$XDG_CURRENT_DESKTOP" in
            "XFCE")
                echo "  • Para XFCE: Revisa en Aplicaciones → Internet"
                ;;
            "GNOME")
                echo "  • Para GNOME: Presiona Super y busca 'Chrome'"
                ;;
            "KDE"|"plasma")
                echo "  • Para KDE: Revisa en el Lanzador de aplicaciones"
                ;;
            *)
                echo "  • Busca 'Google Chrome' en tu menú de aplicaciones"
                ;;
        esac
    fi
    
    echo
    
    if [[ "$1" == "first_install" ]]; then
        print_warning "Primera instalación detectada:"
        print_warning "1. Cierra sesión y vuelve a entrar para garantizar que aparezca el icono"
        print_warning "2. O ejecuta 'hash -r' para actualizar el PATH"
        print_warning "3. Si no aparece el icono, reinicia tu entorno de escritorio"
    fi
    
    echo
    print_status "Para probar Chrome, ejecuta: google-chrome"
}

main() {
    print_status "Script de instalación/actualización de Google Chrome RPM para Void Linux"
    echo
    
    check_root
    check_dependencies
    
    local installed_version=$(get_installed_version)
    local is_first_install=false
    
    if [[ "$installed_version" == "not_installed" ]]; then
        print_status "Google Chrome no está instalado. Procediendo con la instalación..."
        is_first_install=true
    else
        print_status "Google Chrome versión $installed_version está instalado."
        
        # Verificar si hay actualizaciones disponibles
        local latest_version=$(get_latest_version)
        
        if [[ "$latest_version" != "latest" && "$installed_version" == "$latest_version" ]]; then
            print_success "Google Chrome ya está en la última versión ($installed_version)"
            
            # Verificar que el icono esté disponible
            if [[ ! -f /usr/share/applications/google-chrome.desktop ]]; then
                print_warning "Archivo .desktop faltante, recreando..."
                create_desktop_entry
                update_system_caches
                print_success "Icono de aplicación restaurado"
            fi
            
            cleanup
            exit 0
        else
            print_status "Procediendo con la actualización..."
        fi
    fi
    
    # Crear directorio temporal
    mkdir -p "$TEMP_DIR"
    
    # Instalar dependencias de runtime
    install_runtime_dependencies
    
    # Descargar y extraer Chrome
    download_and_extract_chrome
    
    # Instalar Chrome
    install_chrome
    
    # Verificar instalación
    sleep 2
    if verify_installation; then
        if [[ "$is_first_install" == true ]]; then
            show_post_install_info "first_install"
        else
            show_post_install_info "update"
        fi
    else
        print_error "La instalación no se completó correctamente"
        exit 1
    fi
    
    cleanup
}

# Manejar señales para cleanup
trap cleanup EXIT INT TERM

# Ejecutar función principal
main "$@"