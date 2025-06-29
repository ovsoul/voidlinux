#!/bin/bash

# ============================================================================
# Script Configurador Automático de PipeWire para Void Linux + KDE
# Versión: 2.0
# Autor: Asistente Claude
# ============================================================================

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variables globales
SCRIPT_NAME="$(basename "$0")"
LOG_FILE="/tmp/pipewire_setup_$(date +%Y%m%d_%H%M%S).log"
USER_RUNSVDIR="$HOME/.config/runit/runsvdir/default"
ISSUES_FOUND=()
ACTIONS_TAKEN=()

# ============================================================================
# FUNCIONES DE UTILIDAD
# ============================================================================

log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$LOG_FILE"
}

print_header() {
    echo -e "${CYAN}============================================================================${NC}"
    echo -e "${CYAN}  🎵 CONFIGURADOR AUTOMÁTICO DE PIPEWIRE PARA VOID LINUX + KDE${NC}"
    echo -e "${CYAN}============================================================================${NC}"
    echo -e "${YELLOW}Log file: $LOG_FILE${NC}"
    echo ""
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log_message "INFO" "$1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
    log_message "SUCCESS" "$1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
    log_message "WARNING" "$1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
    log_message "ERROR" "$1"
}

ask_user() {
    local question="$1"
    local default="$2"
    echo -e "${PURPLE}[?]${NC} $question"
    if [[ -n "$default" ]]; then
        echo -e "${CYAN}    Sugerencia: $default${NC}"
    fi
    read -p "    Respuesta: " user_response
    echo "$user_response"
}

confirm_action() {
    local action="$1"
    echo -e "${YELLOW}[CONFIRMACIÓN]${NC} $action"
    read -p "¿Continuar? (s/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# FUNCIONES DE VERIFICACIÓN
# ============================================================================

check_void_linux() {
    print_status "Verificando sistema Void Linux..."
    if [[ -f /etc/os-release ]]; then
        if grep -q "void" /etc/os-release 2>/dev/null; then
            print_success "Sistema Void Linux detectado"
            return 0
        fi
    fi
    
    if command -v xbps-install >/dev/null 2>&1; then
        print_success "Sistema Void Linux detectado (xbps encontrado)"
        return 0
    fi
    
    print_error "No se detectó Void Linux. Este script está diseñado específicamente para Void."
    return 1
}

check_kde_session() {
    print_status "Verificando sesión KDE..."
    
    if [[ "$XDG_CURRENT_DESKTOP" == *"KDE"* ]] || [[ "$DESKTOP_SESSION" == *"plasma"* ]]; then
        print_success "Sesión KDE detectada"
        return 0
    fi
    
    if pgrep -x "plasmashell" >/dev/null 2>&1; then
        print_success "KDE Plasma detectado (proceso plasmashell activo)"
        return 0
    fi
    
    print_warning "No se detectó una sesión KDE activa"
    local response=$(ask_user "¿Deseas continuar de todos modos? Este script está optimizado para KDE." "Recomiendo instalar KDE primero")
    
    if [[ "$response" =~ ^[Ss].*|^[Yy].* ]]; then
        ISSUES_FOUND+=("KDE no detectado pero usuario decidió continuar")
        return 0
    else
        return 1
    fi
}

check_root_permissions() {
    print_status "Verificando permisos..."
    if [[ $EUID -eq 0 ]]; then
        print_error "No ejecutes este script como root. Se solicitarán permisos sudo cuando sea necesario."
        return 1
    fi
    
    if ! sudo -n true 2>/dev/null; then
        print_status "Se requieren permisos sudo. Por favor, ingresa tu contraseña:"
        if ! sudo true; then
            print_error "No se pudieron obtener permisos sudo"
            return 1
        fi
    fi
    
    print_success "Permisos verificados correctamente"
    return 0
}

check_internet_connection() {
    print_status "Verificando conexión a internet..."
    if ping -c 1 repo-default.voidlinux.org >/dev/null 2>&1; then
        print_success "Conexión a repositorios Void OK"
        return 0
    elif ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        print_warning "Internet OK pero repositorios Void no accesibles"
        return 0
    else
        print_error "Sin conexión a internet"
        return 1
    fi
}

# ============================================================================
# FUNCIONES DE ANÁLISIS DEL SISTEMA
# ============================================================================

analyze_current_audio() {
    print_status "Analizando configuración de audio actual..."
    
    # Verificar PulseAudio activo
    if pgrep -x "pulseaudio" >/dev/null 2>&1; then
        print_warning "PulseAudio está ejecutándose. Será necesario detenerlo."
        ISSUES_FOUND+=("PulseAudio activo - conflicto con PipeWire")
    fi
    
    # Verificar ALSA
    if [[ -f /proc/asound/cards ]]; then
        local cards_count=$(grep -c "^[[:space:]]*[0-9]" /proc/asound/cards 2>/dev/null || echo "0")
        if [[ $cards_count -gt 0 ]]; then
            print_success "Tarjetas de audio ALSA detectadas: $cards_count"
        else
            print_warning "No se detectaron tarjetas de audio ALSA"
            ISSUES_FOUND+=("Sin tarjetas de audio ALSA detectadas")
        fi
    fi
    
    # Verificar PipeWire existente
    if command -v pipewire >/dev/null 2>&1; then
        print_warning "PipeWire ya está instalado. Verificando configuración..."
        if pgrep -x "pipewire" >/dev/null 2>&1; then
            print_success "PipeWire está ejecutándose"
        else
            print_warning "PipeWire instalado pero no ejecutándose"
            ISSUES_FOUND+=("PipeWire instalado pero no activo")
        fi
    fi
}

analyze_directories() {
    print_status "Analizando estructura de directorios..."
    
    # Verificar directorio de configuración runit del usuario
    if [[ ! -d "$USER_RUNSVDIR" ]]; then
        print_warning "Directorio de servicios de usuario no existe: $USER_RUNSVDIR"
        ISSUES_FOUND+=("Falta directorio de servicios de usuario")
    else
        print_success "Directorio de servicios de usuario existe"
    fi
    
    # Verificar directorio de configuración XDG
    if [[ ! -d "$HOME/.config" ]]; then
        print_warning "Directorio .config no existe"
        ISSUES_FOUND+=("Falta directorio .config")
    fi
    
    # Verificar grupos de usuario
    local audio_group=$(groups | grep -o "audio" || echo "")
    if [[ -z "$audio_group" ]]; then
        print_warning "Usuario no está en el grupo 'audio'"
        ISSUES_FOUND+=("Usuario no en grupo audio")
    else
        print_success "Usuario está en el grupo audio"
    fi
}

# ============================================================================
# FUNCIONES DE CORRECCIÓN
# ============================================================================

create_missing_directories() {
    print_status "Creando directorios faltantes..."
    
    if [[ ! -d "$HOME/.config" ]]; then
        mkdir -p "$HOME/.config"
        print_success "Creado directorio .config"
        ACTIONS_TAKEN+=("Creado directorio .config")
    fi
    
    if [[ ! -d "$USER_RUNSVDIR" ]]; then
        mkdir -p "$USER_RUNSVDIR"
        print_success "Creado directorio de servicios de usuario: $USER_RUNSVDIR"
        ACTIONS_TAKEN+=("Creado directorio de servicios de usuario")
    fi
    
    # Crear directorio de logs si no existe
    if [[ ! -d "$HOME/.local/share/logs" ]]; then
        mkdir -p "$HOME/.local/share/logs"
        print_success "Creado directorio de logs"
    fi
}

stop_conflicting_services() {
    print_status "Deteniendo servicios de audio conflictivos..."
    
    # Detener PulseAudio si está activo
    if pgrep -x "pulseaudio" >/dev/null 2>&1; then
        print_status "Deteniendo PulseAudio..."
        pulseaudio --kill 2>/dev/null || true
        sleep 2
        if ! pgrep -x "pulseaudio" >/dev/null 2>&1; then
            print_success "PulseAudio detenido correctamente"
            ACTIONS_TAKEN+=("PulseAudio detenido")
        else
            print_warning "PulseAudio aún ejecutándose"
        fi
    fi
}

install_pipewire_packages() {
    print_status "Instalando paquetes de PipeWire..."
    
    local packages=(
        "pipewire"
        "alsa-pipewire" 
        "libjack-pipewire"
        "pipewire-pulse"
        "plasma-pa"
        "pavucontrol"
        "alsa-utils"
    )
    
    # Actualizar repositorios
    print_status "Actualizando repositorios..."
    if sudo xbps-install -S; then
        print_success "Repositorios actualizados"
    else
        print_warning "Error actualizando repositorios, continuando..."
    fi
    
    # Instalar paquetes
    for package in "${packages[@]}"; do
        print_status "Instalando $package..."
        if sudo xbps-install -y "$package"; then
            print_success "$package instalado correctamente"
            ACTIONS_TAKEN+=("Instalado $package")
        else
            print_error "Error instalando $package"
            local response=$(ask_user "¿Continuar sin $package?" "No recomendado, pero posible")
            if [[ ! "$response" =~ ^[Ss].*|^[Yy].* ]]; then
                return 1
            fi
        fi
    done
}

configure_alsa_alternatives() {
    print_status "Configurando alternativas ALSA..."
    
    if sudo xbps-alternatives --set alsa-lib-pipewire; then
        print_success "Alternativas ALSA configuradas para PipeWire"
        ACTIONS_TAKEN+=("Configuradas alternativas ALSA")
    else
        print_warning "Error configurando alternativas ALSA"
        ISSUES_FOUND+=("Error en alternativas ALSA")
    fi
}

setup_user_services() {
    print_status "Configurando servicios de usuario..."
    
    # Servicios para habilitar
    local services=("pipewire" "pipewire-pulse")
    
    for service in "${services[@]}"; do
        local service_link="$USER_RUNSVDIR/$service"
        if [[ ! -L "$service_link" ]]; then
            if [[ -d "/etc/sv/$service" ]]; then
                ln -sf "/etc/sv/$service" "$service_link"
                print_success "Servicio $service habilitado para usuario"
                ACTIONS_TAKEN+=("Habilitado servicio $service")
            else
                print_warning "Servicio $service no encontrado en /etc/sv/"
            fi
        else
            print_success "Servicio $service ya está habilitado"
        fi
    done
}

add_user_to_audio_group() {
    print_status "Verificando membresía en grupo audio..."
    
    if ! groups | grep -q "audio"; then
        print_status "Agregando usuario al grupo audio..."
        if sudo usermod -a -G audio "$USER"; then
            print_success "Usuario agregado al grupo audio"
            ACTIONS_TAKEN+=("Usuario agregado a grupo audio")
            print_warning "Será necesario cerrar sesión y volver a entrar para que el cambio tenga efecto"
        else
            print_error "Error agregando usuario al grupo audio"
            ISSUES_FOUND+=("Error agregando usuario a grupo audio")
        fi
    else
        print_success "Usuario ya está en el grupo audio"
    fi
}

# ============================================================================
# FUNCIONES DE VERIFICACIÓN POST-INSTALACIÓN
# ============================================================================

test_audio_system() {
    print_status "Probando sistema de audio..."
    
    # Esperar un poco para que los servicios se inicien
    sleep 3
    
    # Verificar que PipeWire esté ejecutándose
    if pgrep -x "pipewire" >/dev/null 2>&1; then
        print_success "PipeWire está ejecutándose"
    else
        print_warning "PipeWire no está ejecutándose"
        return 1
    fi
    
    # Verificar que pipewire-pulse esté ejecutándose
    if pgrep -x "pipewire-pulse" >/dev/null 2>&1; then
        print_success "PipeWire-Pulse está ejecutándose"
    else
        print_warning "PipeWire-Pulse no está ejecutándose"
    fi
    
    # Probar si podemos listar dispositivos de audio
    if command -v pactl >/dev/null 2>&1; then
        if pactl info >/dev/null 2>&1; then
            print_success "PulseAudio API (PipeWire-Pulse) respondiendo"
            
            # Mostrar dispositivos disponibles
            print_status "Dispositivos de audio disponibles:"
            pactl list short sinks 2>/dev/null | while read line; do
                echo -e "${CYAN}    $line${NC}"
            done
        else
            print_warning "PulseAudio API no responde"
        fi
    fi
    
    return 0
}

# ============================================================================
# FUNCIÓN PRINCIPAL DE DIAGNÓSTICO INTELIGENTE
# ============================================================================

intelligent_diagnosis() {
    print_status "Realizando diagnóstico inteligente del sistema..."
    
    echo -e "\n${YELLOW}=== DIAGNÓSTICO INTELIGENTE ===${NC}"
    
    # Mostrar problemas encontrados
    if [[ ${#ISSUES_FOUND[@]} -gt 0 ]]; then
        echo -e "\n${RED}Problemas detectados:${NC}"
        for issue in "${ISSUES_FOUND[@]}"; do
            echo -e "  ${RED}•${NC} $issue"
        done
        
        echo -e "\n${YELLOW}Análisis y recomendaciones:${NC}"
        
        # Análisis inteligente basado en los problemas
        for issue in "${ISSUES_FOUND[@]}"; do
            case "$issue" in
                *"PulseAudio activo"*)
                    echo -e "  ${CYAN}•${NC} PulseAudio conflicta con PipeWire. Será detenido automáticamente."
                    ;;
                *"Sin tarjetas de audio"*)
                    echo -e "  ${CYAN}•${NC} Posible problema de hardware o drivers. Verificar con 'lspci | grep -i audio'"
                    ;;
                *"no en grupo audio"*)
                    echo -e "  ${CYAN}•${NC} Sin permisos de audio. Se agregará automáticamente al grupo."
                    ;;
                *"directorio de servicios"*)
                    echo -e "  ${CYAN}•${NC} Configuración de servicios incompleta. Se creará automáticamente."
                    ;;
            esac
        done
        
        if ! confirm_action "Se han detectado problemas. ¿Proceder con las correcciones automáticas?"; then
            return 1
        fi
    else
        print_success "No se detectaron problemas críticos"
    fi
    
    return 0
}

# ============================================================================
# FUNCIÓN DE CONSULTA INTERACTIVA
# ============================================================================

interactive_consultation() {
    echo -e "\n${PURPLE}=== CONSULTA INTERACTIVA ===${NC}"
    echo -e "${CYAN}¿Tienes alguna pregunta específica sobre la configuración?${NC}"
    echo -e "${YELLOW}Opciones disponibles:${NC}"
    echo -e "  1) ¿Qué hace cada paquete que se va a instalar?"
    echo -e "  2) ¿Por qué se necesita detener PulseAudio?"
    echo -e "  3) ¿Qué son los servicios de usuario en runit?"
    echo -e "  4) ¿Cómo verificar que todo funciona después?"
    echo -e "  5) Continuar con la instalación"
    echo -e "  6) Salir"
    
    while true; do
        read -p "Elige una opción (1-6): " choice
        case $choice in
            1)
                echo -e "\n${CYAN}Explicación de paquetes:${NC}"
                echo -e "• ${YELLOW}pipewire${NC}: El servidor de audio principal"
                echo -e "• ${YELLOW}alsa-pipewire${NC}: Compatibilidad con aplicaciones ALSA"
                echo -e "• ${YELLOW}libjack-pipewire${NC}: Compatibilidad con aplicaciones JACK"
                echo -e "• ${YELLOW}pipewire-pulse${NC}: Emulación PulseAudio para compatibilidad"
                echo -e "• ${YELLOW}plasma-pa${NC}: Control de volumen integrado en KDE"
                echo -e "• ${YELLOW}pavucontrol${NC}: Mezclador de audio gráfico"
                ;;
            2)
                echo -e "\n${CYAN}Sobre PulseAudio vs PipeWire:${NC}"
                echo -e "PulseAudio y PipeWire no pueden ejecutarse simultáneamente ya que"
                echo -e "ambos intentan controlar el mismo hardware de audio. PipeWire es"
                echo -e "más moderno y eficiente, por eso reemplazamos PulseAudio."
                ;;
            3)
                echo -e "\n${CYAN}Servicios de usuario en runit:${NC}"
                echo -e "Void Linux usa runit como sistema de init. Los servicios de usuario"
                echo -e "se ejecutan en ~/.config/runit/runsvdir/default/ y se inician"
                echo -e "automáticamente cuando inicias sesión."
                ;;
            4)
                echo -e "\n${CYAN}Verificación post-instalación:${NC}"
                echo -e "• Ejecutar 'pactl info' para verificar que PipeWire responde"
                echo -e "• Abrir configuración de sonido en KDE"
                echo -e "• Probar reproducir audio"
                echo -e "• Verificar que aparecen controles de volumen"
                ;;
            5)
                return 0
                ;;
            6)
                print_status "Saliendo del script..."
                exit 0
                ;;
            *)
                echo -e "${RED}Opción inválida. Elige 1-6.${NC}"
                ;;
        esac
        echo ""
    done
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    print_header
    
    # Verificaciones iniciales
    check_void_linux || exit 1
    check_root_permissions || exit 1
    check_internet_connection || exit 1
    check_kde_session || exit 1
    
    # Análisis del sistema
    analyze_current_audio
    analyze_directories
    
    # Diagnóstico inteligente
    intelligent_diagnosis || exit 1
    
    # Consulta interactiva
    interactive_consultation
    
    echo -e "\n${CYAN}=== INICIANDO CONFIGURACIÓN AUTOMÁTICA ===${NC}"
    
    # Correcciones y configuración
    create_missing_directories
    stop_conflicting_services
    add_user_to_audio_group
    install_pipewire_packages || exit 1
    configure_alsa_alternatives
    setup_user_services
    
    # Verificación final
    echo -e "\n${CYAN}=== VERIFICACIÓN FINAL ===${NC}"
    test_audio_system
    
    # Resumen final
    echo -e "\n${GREEN}=== RESUMEN DE ACCIONES REALIZADAS ===${NC}"
    if [[ ${#ACTIONS_TAKEN[@]} -gt 0 ]]; then
        for action in "${ACTIONS_TAKEN[@]}"; do
            echo -e "  ${GREEN}✓${NC} $action"
        done
    else
        echo -e "  ${YELLOW}No se realizaron acciones (sistema ya configurado)${NC}"
    fi
    
    echo -e "\n${CYAN}=== PASOS FINALES ===${NC}"
    echo -e "${YELLOW}1.${NC} Reinicia tu sesión KDE (cerrar sesión y volver a entrar)"
    echo -e "${YELLOW}2.${NC} Abre Configuración del Sistema → Multimedia → Audio"
    echo -e "${YELLOW}3.${NC} Verifica que aparezcan tus dispositivos de audio"
    echo -e "${YELLOW}4.${NC} Prueba reproducir audio"
    
    echo -e "\n${GREEN}¡Configuración completada!${NC}"
    echo -e "${CYAN}Log guardado en: $LOG_FILE${NC}"
    
    if [[ ${#ISSUES_FOUND[@]} -gt 0 ]]; then
        echo -e "\n${YELLOW}Si tienes problemas, revisa el log y considera ejecutar:${NC}"
        echo -e "  ${CYAN}sv status pipewire pipewire-pulse${NC}"
        echo -e "  ${CYAN}pactl info${NC}"
    fi
}

# ============================================================================
# MANEJO DE SEÑALES Y LIMPIEZA
# ============================================================================

cleanup() {
    echo -e "\n${YELLOW}Script interrumpido. Log guardado en: $LOG_FILE${NC}"
    exit 1
}

trap cleanup INT TERM

# ============================================================================
# EJECUCIÓN PRINCIPAL
# ============================================================================

# Verificar si se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi