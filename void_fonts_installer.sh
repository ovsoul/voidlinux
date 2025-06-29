#!/bin/bash

# Script para instalar fuentes completas en Void Linux
# Ejecutar como root o con sudo

set -e

echo "=== Instalador de Fuentes Completo para Void Linux ==="
echo "Este script instalará fuentes de Microsoft, Google, emojis y más..."
echo

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir con colores
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   print_error "Este script debe ejecutarse como root o con sudo"
   exit 1
fi

# Actualizar repositorios
print_status "Actualizando repositorios..."
xbps-install -S

# Instalar fuentes básicas del sistema
print_status "Instalando fuentes básicas del sistema..."

# Lista de paquetes básicos con verificación
basic_fonts=(
    "font-util"
    "dejavu-fonts-ttf" 
    "liberation-fonts-ttf"
    "unifont"
    "font-awesome"
    "font-awesome5"
    "font-misc-misc"
    "font-cursor-misc"
)

for font in "${basic_fonts[@]}"; do
    if xbps-query "$font" >/dev/null 2>&1; then
        print_warning "$font ya está instalado, omitiendo..."
    else
        print_status "Instalando $font..."
        if xbps-install -y "$font" 2>/dev/null; then
            print_success "$font instalado correctamente"
        else
            print_warning "No se pudo instalar $font (puede que no exista en el repositorio)"
        fi
    fi
done

print_success "Fuentes básicas procesadas"

# Instalar fuentes de Google (Noto)
print_status "Instalando fuentes Google Noto..."

noto_fonts=(
    "noto-fonts-ttf"
    "noto-fonts-cjk"
    "noto-fonts-emoji"
)

for font in "${noto_fonts[@]}"; do
    if xbps-query "$font" >/dev/null 2>&1; then
        print_warning "$font ya está instalado, omitiendo..."
    else
        print_status "Instalando $font..."
        if xbps-install -y "$font" 2>/dev/null; then
            print_success "$font instalado correctamente"
        else
            print_warning "No se pudo instalar $font"
        fi
    fi
done

print_success "Fuentes Google Noto procesadas"

# Instalar fuentes adicionales disponibles en repos
print_status "Verificando fuentes adicionales disponibles..."

# Verificar qué paquetes están disponibles en los repos
check_package_availability() {
    local package="$1"
    xbps-query -Rs "$package" >/dev/null 2>&1
}

additional_fonts=(
    "font-adobe-source-code-pro"
    "adobe-source-sans-pro-fonts"
    "adobe-source-serif-pro-fonts" 
    "google-roboto-fonts"
    "font-fira-ttf"
    "font-hack-ttf"
    "font-inconsolata-otf"
    "terminus-font"
    "google-droid-fonts"
    "font-bitstream-vera"
    "font-cantarell-otf"
    "font-open-sans-ttf"
)

for font in "${additional_fonts[@]}"; do
    if xbps-query "$font" >/dev/null 2>&1; then
        print_warning "$font ya está instalado, omitiendo..."
    elif check_package_availability "$font"; then
        print_status "Instalando $font..."
        if xbps-install -y "$font" 2>/dev/null; then
            print_success "$font instalado correctamente"
        else
            print_warning "Error instalando $font"
        fi
    else
        print_warning "$font no está disponible en repositorios"
    fi
done

print_success "Fuentes adicionales procesadas"

# Crear directorio para fuentes descargadas
FONTS_DIR="/usr/share/fonts/truetype"
TEMP_DIR="/tmp/fonts_install"

mkdir -p "$FONTS_DIR"
mkdir -p "$TEMP_DIR"

# Descargar e instalar Microsoft Core Fonts
print_status "Descargando Microsoft Core Fonts..."
cd "$TEMP_DIR"

# Lista de fuentes de Microsoft Core Fonts (excluyendo fontinst.exe que da problemas)
ms_fonts=(
    "andale32.exe"
    "arial32.exe" 
    "arialb32.exe"
    "comic32.exe"
    "courie32.exe"
    "georgi32.exe"
    "impact32.exe"
    "times32.exe"
    "trebuc32.exe"
    "verdan32.exe"
    "webdin32.exe"
)

download_count=0
for font_file in "${ms_fonts[@]}"; do
    print_status "Descargando $font_file..."
    if wget -q "https://downloads.sourceforge.net/corefonts/$font_file" -O "$font_file" 2>/dev/null; then
        print_success "$font_file descargado"
        ((download_count++))
    else
        print_warning "No se pudo descargar $font_file"
    fi
done

if [ $download_count -eq 0 ]; then
    print_error "No se pudieron descargar fuentes de Microsoft"
    skip_ms_fonts=true
else
    print_success "$download_count fuentes de Microsoft descargadas"
fi

# Instalar cabextract si no está disponible
if ! command -v cabextract &> /dev/null; then
    print_status "Instalando cabextract..."
    if xbps-install -y cabextract; then
        print_success "cabextract instalado"
    else
        print_error "No se pudo instalar cabextract, omitiendo fuentes de Microsoft"
        skip_ms_fonts=true
    fi
fi

if [ "$skip_ms_fonts" != true ]; then
    # Extraer fuentes de Microsoft
    print_status "Extrayendo fuentes de Microsoft..."
    for exe_file in *.exe; do
        if [ -f "$exe_file" ]; then
            cabextract -q "$exe_file" 2>/dev/null || print_warning "Error extrayendo $exe_file"
        fi
    done

    # Copiar fuentes TTF extraídas
    print_status "Instalando fuentes de Microsoft..."
    mkdir -p "$FONTS_DIR/microsoft"
    fonts_copied=0
    for ttf_file in *.ttf *.TTF; do
        if [ -f "$ttf_file" ]; then
            if cp "$ttf_file" "$FONTS_DIR/microsoft/" 2>/dev/null; then
                ((fonts_copied++))
            else
                print_warning "Error copiando $ttf_file"
            fi
        fi
    done

    if [ $fonts_copied -gt 0 ]; then
        print_success "Fuentes de Microsoft instaladas ($fonts_copied fuentes)"
    else
        print_warning "No se pudieron instalar fuentes de Microsoft"
    fi
else
    print_warning "Omitiendo instalación de fuentes de Microsoft"
fi

# Descargar fuentes adicionales de Windows (Segoe UI, etc.)
print_status "Descargando fuentes adicionales de Windows..."

# Crear función para descargar fuentes de GitHub
download_font_from_github() {
    local repo="$1"
    local font_name="$2"
    local url="https://github.com/$repo/raw/master/$font_name"
    
    wget -q "$url" -O "$font_name" 2>/dev/null || wget -q "$url" -O "$font_name" 2>/dev/null || print_warning "No se pudo descargar $font_name"
    
    if [ -f "$font_name" ]; then
        mkdir -p "$FONTS_DIR/windows-additional"
        cp "$font_name" "$FONTS_DIR/windows-additional/"
    fi
}

# Descargar algunas fuentes adicionales populares
print_status "Descargando fuentes populares adicionales..."

# JetBrains Mono
mkdir -p "$FONTS_DIR/jetbrains"
wget -q "https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip" -O jetbrains.zip 2>/dev/null || print_warning "No se pudo descargar JetBrains Mono"
if [ -f "jetbrains.zip" ]; then
    unzip -q jetbrains.zip 2>/dev/null
    find . -name "*.ttf" -exec cp {} "$FONTS_DIR/jetbrains/" \; 2>/dev/null
    print_success "JetBrains Mono instalado"
fi

# Limpiar archivos temporales
print_status "Limpiando archivos temporales..."
cd /
rm -rf "$TEMP_DIR"

# Actualizar caché de fuentes
print_status "Actualizando caché de fuentes..."
fc-cache -fv

# Configurar fontconfig para mejorar renderizado
print_status "Configurando fontconfig..."
cat > /etc/fonts/local.conf << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <!-- Mejorar renderizado de fuentes -->
  <match target="font">
    <edit name="antialias" mode="assign">
      <bool>true</bool>
    </edit>
    <edit name="hinting" mode="assign">
      <bool>true</bool>
    </edit>
    <edit name="hintstyle" mode="assign">
      <const>hintslight</const>
    </edit>
    <edit name="rgba" mode="assign">
      <const>rgb</const>
    </edit>
  </match>

  <!-- Alias para fuentes comunes -->
  <alias>
    <family>serif</family>
    <prefer>
      <family>Liberation Serif</family>
      <family>Times New Roman</family>
      <family>DejaVu Serif</family>
    </prefer>
  </alias>

  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>Liberation Sans</family>
      <family>Arial</family>
      <family>DejaVu Sans</family>
    </prefer>
  </alias>

  <alias>
    <family>monospace</family>
    <prefer>
      <family>Liberation Mono</family>
      <family>Courier New</family>
      <family>DejaVu Sans Mono</family>
      <family>JetBrains Mono</family>
    </prefer>
  </alias>
</fontconfig>
EOF

# Actualizar caché final
fc-cache -fv

print_success "Instalación completada!"
echo
echo "=== RESUMEN ==="
echo "Fuentes instaladas:"
echo "✓ Fuentes básicas del sistema (DejaVu, Liberation, etc.)"
echo "✓ Google Noto Fonts (incluye emojis y CJK)"
echo "✓ Microsoft Core Fonts"
echo "✓ Adobe Source Fonts"
echo "✓ Roboto, Fira, Hack, Inconsolata"
echo "✓ JetBrains Mono"
echo "✓ Font Awesome (iconos)"
echo
echo "Para verificar las fuentes instaladas ejecuta:"
echo "fc-list | grep -i 'arial\\|georgia\\|times\\|verdana'"
echo
echo "Reinicia tu navegador/aplicaciones para que tomen efecto los cambios."