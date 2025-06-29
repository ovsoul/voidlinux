#!/bin/bash

# Script para diagnosticar y reparar el icono de Google Chrome en XFCE/Void Linux

set -e

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
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

diagnostic_check() {
    print_status "=== DIAGNÓSTICO COMPLETO ==="
    echo
    
    # 1. Verificar Chrome instalado
    print_status "1. Verificando instalación de Chrome..."
    if command -v google-chrome &> /dev/null; then
        local version=$(google-chrome --version 2>/dev/null || echo "Error al obtener versión")
        print_success "Chrome instalado: $version"
    else
        print_error "Chrome no está instalado o no está en PATH"
        return 1
    fi
    
    # 2. Verificar ejecutable
    print_status "2. Verificando ejecutable..."
    if [[ -f /opt/google/chrome/google-chrome ]]; then
        print_success "Ejecutable encontrado: /opt/google/chrome/google-chrome"
        ls -la /opt/google/chrome/google-chrome
    else
        print_error "Ejecutable no encontrado en /opt/google/chrome/google-chrome"
    fi
    
    # 3. Verificar archivo .desktop
    print_status "3. Verificando archivo .desktop..."
    local desktop_file="/usr/share/applications/google-chrome.desktop"
    if [[ -f "$desktop_file" ]]; then
        print_success "Archivo .desktop encontrado"
        ls -la "$desktop_file"
        echo "--- Contenido del archivo ---"
        cat "$desktop_file"
        echo "--- Fin del contenido ---"
    else
        print_error "Archivo .desktop NO encontrado"
    fi
    
    # 4. Verificar iconos
    print_status "4. Verificando iconos..."
    find /usr/share/icons -name "*chrome*" -type f 2>/dev/null | head -10
    find /opt/google/chrome -name "*.png" -type f 2>/dev/null | head -5
    
    # 5. Verificar entorno XFCE
    print_status "5. Verificando entorno XFCE..."
    echo "XDG_CURRENT_DESKTOP: ${XDG_CURRENT_DESKTOP:-No definido}"
    echo "XDG_DATA_DIRS: ${XDG_DATA_DIRS:-No definido}"
    
    # 6. Verificar cache de aplicaciones
    print_status "6. Verificando cache de aplicaciones..."
    if command -v update-desktop-database &> /dev/null; then
        print_success "update-desktop-database disponible"
    else
        print_warning "update-desktop-database no disponible"
    fi
    
    # 7. Verificar procesos XFCE
    print_status "7. Verificando procesos XFCE..."
    ps aux | grep -E "(xfce4-panel|xfdesktop|xfce4-appfinder)" | grep -v grep || echo "No se encontraron procesos XFCE activos"
    
    echo
    print_status "=== FIN DEL DIAGNÓSTICO ==="
}

create_desktop_file() {
    print_status "Creando archivo .desktop optimizado para XFCE..."
    
    local desktop_file="/usr/share/applications/google-chrome.desktop"
    
    sudo tee "$desktop_file" > /dev/null << 'EOF'
[Desktop Entry]
Version=1.0
Name=Google Chrome
Name[es]=Google Chrome
GenericName=Web Browser
GenericName[es]=Navegador Web
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
Actions=NewWindow;NewPrivateWindow;

[Desktop Action NewWindow]
Name=New Window
Name[es]=Nueva Ventana
Exec=/opt/google/chrome/google-chrome

[Desktop Action NewPrivateWindow]
Name=New Private Window
Name[es]=Nueva Ventana Privada
Exec=/opt/google/chrome/google-chrome --incognito
EOF
    
    sudo chmod 644 "$desktop_file"
    print_success "Archivo .desktop creado"
}

fix_icons() {
    print_status "Reparando iconos..."
    
    # Verificar si los iconos de Chrome existen
    local chrome_icons_dir="/opt/google/chrome"
    if [[ -d "$chrome_icons_dir" ]]; then
        # Crear enlaces simbólicos para los iconos si no existen
        local icon_sizes=("16" "22" "24" "32" "48" "64" "128" "256")
        
        for size in "${icon_sizes[@]}"; do
            local target_dir="/usr/share/icons/hicolor/${size}x${size}/apps"
            local source_icon="$chrome_icons_dir/product_logo_${size}.png"
            local target_icon="$target_dir/google-chrome.png"
            
            if [[ -f "$source_icon" && ! -f "$target_icon" ]]; then
                sudo mkdir -p "$target_dir"
                sudo cp "$source_icon" "$target_icon"
                print_success "Icono ${size}x${size} copiado"
            fi
        done
        
        # Buscar el icono principal si no se encontraron los específicos
        local main_icon=$(find "$chrome_icons_dir" -name "*.png" -type f | head -1)
        if [[ -n "$main_icon" ]]; then
            sudo mkdir -p /usr/share/pixmaps
            sudo cp "$main_icon" /usr/share/pixmaps/google-chrome.png
            print_success "Icono principal copiado a /usr/share/pixmaps/"
        fi
    fi
}

update_xfce_caches() {
    print_status "Actualizando caches de XFCE..."
    
    # Actualizar base de datos de aplicaciones
    sudo update-desktop-database /usr/share/applications/ 2>/dev/null || true
    
    # Actualizar cache de iconos
    sudo gtk-update-icon-cache -f /usr/share/icons/hicolor/ 2>/dev/null || true
    
    # Limpiar cache personal de XFCE
    rm -rf ~/.cache/xfce4/desktop/ 2>/dev/null || true
    rm -rf ~/.cache/sessions/xfce4-session-* 2>/dev/null || true
    
    # Recargar específicamente para XFCE
    if command -v xfce4-appfinder &> /dev/null; then
        xfce4-appfinder --reload 2>/dev/null || true
        print_success "Cache de aplicaciones XFCE recargado"
    fi
    
    # Reiniciar panel XFCE
    if pgrep xfce4-panel > /dev/null; then
        killall -USR1 xfce4-panel 2>/dev/null || true
        print_success "Panel XFCE reiniciado"
    fi
    
    # Reiniciar escritorio XFCE
    if pgrep xfdesktop > /dev/null; then
        killall -USR1 xfdesktop 2>/dev/null || true
        print_success "Escritorio XFCE reiniciado"
    fi
}

create_desktop_shortcut() {
    print_status "Creando acceso directo en el escritorio..."
    
    local desktop_dir="$HOME/Escritorio"
    if [[ ! -d "$desktop_dir" ]]; then
        desktop_dir="$HOME/Desktop"
    fi
    
    if [[ -d "$desktop_dir" ]]; then
        cp /usr/share/applications/google-chrome.desktop "$desktop_dir/"
        chmod +x "$desktop_dir/google-chrome.desktop"
        print_success "Acceso directo creado en $desktop_dir"
    else
        print_warning "No se pudo encontrar el directorio del escritorio"
    fi
}

manual_menu_check() {
    print_status "Instrucciones para verificar manualmente..."
    echo
    echo "1. Abre el menú de aplicaciones de XFCE"
    echo "2. Ve a Aplicaciones → Internet"
    echo "3. Busca 'Google Chrome'"
    echo
    echo "También puedes:"
    echo "- Presionar Alt+F2 y escribir 'google-chrome'"
    echo "- Usar el buscador de aplicaciones (Ctrl+Alt+A)"
    echo "- Buscar en Configuración → Aplicaciones preferidas"
    echo
    print_warning "Si aún no aparece, cierra sesión y vuelve a entrar"
}

main() {
    print_status "Script de diagnóstico y reparación del icono de Chrome en XFCE"
    echo
    
    # Verificar que estamos en XFCE
    if [[ "$XDG_CURRENT_DESKTOP" != "XFCE" ]]; then
        print_warning "Este script está optimizado para XFCE, pero continuará..."
    fi
    
    # Diagnóstico completo
    diagnostic_check
    
    echo
    print_status "=== INICIANDO REPARACIÓN ==="
    
    # Crear archivo .desktop
    create_desktop_file
    
    # Reparar iconos
    fix_icons
    
    # Actualizar caches
    update_xfce_caches
    
    # Crear acceso directo
    create_desktop_shortcut
    
    echo
    print_success "=== REPARACIÓN COMPLETADA ==="
    
    # Verificación final
    sleep 2
    if [[ -f /usr/share/applications/google-chrome.desktop ]]; then
        print_success "Archivo .desktop verificado"
        
        # Probar si el comando funciona
        if desktop-file-validate /usr/share/applications/google-chrome.desktop 2>/dev/null; then
            print_success "Archivo .desktop es válido"
        else
            print_warning "Archivo .desktop tiene advertencias menores"
        fi
    fi
    
    echo
    manual_menu_check
    
    echo
    print_warning "Si el problema persiste:"
    print_warning "1. Cierra sesión completamente y vuelve a entrar"
    print_warning "2. Reinicia el sistema"
    print_warning "3. Verifica que tienes permisos de lectura en /usr/share/applications/"
}

# Ejecutar
main "$@"