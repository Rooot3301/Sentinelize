#!/bin/bash
#
# Sentinelize - SentinelOne Agent Manager
# Multi-OS Edition (RPM & DEB)
# Author: Root3301
# Version: 3.0
#

set -o pipefail

# ─── Configuration par défaut ──────────────────────────────────────────────────

S1CTL_DEFAULT="/opt/sentinelone/bin/sentinelctl"
SERVICE_NAME_DEFAULT="sentinelone"
AGENT_PACKAGE_DEFAULT="sentinelone-agent"
LOG_FILE_DEFAULT="/var/log/s1-manager.log"
LOG_LEVEL_DEFAULT="INFO"    # ERROR | WARN | INFO | DEBUG

# Chargement optionnel d'un .env à côté du script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

# Variables finales (env > défaut)
S1CTL="${S1CTL:-$S1CTL_DEFAULT}"
SERVICE_NAME="${SERVICE_NAME:-$SERVICE_NAME_DEFAULT}"
AGENT_PACKAGE="${AGENT_PACKAGE:-$AGENT_PACKAGE_DEFAULT}"
LOG_FILE="${LOG_FILE:-$LOG_FILE_DEFAULT}"
LOG_LEVEL="${LOG_LEVEL:-$LOG_LEVEL_DEFAULT}"

# Fichier temporaire global (nettoyé via trap)
TEMP_FILE=""

# ─── Couleurs ──────────────────────────────────────────────────────────────────

GREEN="\e[32m"
RED="\e[31m"
CYAN="\e[36m"
YELLOW="\e[33m"
MAGENTA="\e[35m"
BLUE="\e[34m"
BOLD="\e[1m"
DIM="\e[2m"
RESET="\e[0m"

# ─── Trap nettoyage ────────────────────────────────────────────────────────────

cleanup_temp() {
  if [[ -n "$TEMP_FILE" && -f "$TEMP_FILE" ]]; then
    rm -f "$TEMP_FILE"
  fi
}

trap 'cleanup_temp' EXIT INT TERM

# ─── Détection OS ──────────────────────────────────────────────────────────────

PKG_FAMILY=""    # rpm | deb
PKG_MANAGER=""   # dnf | yum | rpm | apt | apt-get | dpkg
OS_NAME=""
OS_VERSION=""

detect_os() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release 2>/dev/null || true
    OS_NAME="${NAME:-Unknown}"
    OS_VERSION="${VERSION_ID:-}"
    local id_like="${ID_LIKE:-}"
    local id="${ID:-}"

    if echo "$id $id_like" | grep -qiE "rhel|centos|fedora|suse|sles|alma|rocky|oracle"; then
      PKG_FAMILY="rpm"
    elif echo "$id $id_like" | grep -qiE "debian|ubuntu|mint|kali|raspbian"; then
      PKG_FAMILY="deb"
    fi
  fi

  # Fallback par détection des binaires
  if [[ -z "$PKG_FAMILY" ]]; then
    if command -v dpkg &>/dev/null; then
      PKG_FAMILY="deb"
    elif command -v rpm &>/dev/null; then
      PKG_FAMILY="rpm"
    fi
  fi

  # Sélection du package manager préféré
  if [[ "$PKG_FAMILY" == "rpm" ]]; then
    if command -v dnf &>/dev/null; then
      PKG_MANAGER="dnf"
    elif command -v yum &>/dev/null; then
      PKG_MANAGER="yum"
    else
      PKG_MANAGER="rpm"
    fi
  elif [[ "$PKG_FAMILY" == "deb" ]]; then
    if command -v apt &>/dev/null; then
      PKG_MANAGER="apt"
    elif command -v apt-get &>/dev/null; then
      PKG_MANAGER="apt-get"
    else
      PKG_MANAGER="dpkg"
    fi
  fi
}

# ─── Banner ────────────────────────────────────────────────────────────────────

banner() {
  clear
  echo -e "${CYAN}${BOLD}"
  cat << "EOF"
  /$$$$$$                        /$$     /$$                     /$$ /$$
 /$$__  $$                      | $$    |__/                    | $$|__/
| $$  \__/  /$$$$$$  /$$$$$$$  /$$$$$$   /$$ /$$$$$$$   /$$$$$$ | $$ /$$ /$$$$$$$$  /$$$$$$
|  $$$$$$  /$$__  $$| $$__  $$|_  $$_/  | $$| $$__  $$ /$$__  $$| $$| $$|____ /$$/ /$$__  $$
 \____  $$| $$$$$$$$| $$  \ $$  | $$    | $$| $$  \ $$| $$$$$$$$| $$| $$   /$$$$/ | $$$$$$$$
 /$$  \ $$| $$_____/| $$  | $$  | $$ /$$| $$| $$  | $$| $$_____/| $$| $$  /$$__/  | $$_____/
|  $$$$$$/|  $$$$$$$| $$  | $$  |  $$$$/| $$| $$  | $$|  $$$$$$$| $$| $$ /$$$$$$$$|  $$$$$$$
 \______/  \_______/|__/  |__/   \___/  |__/|__/  |__/ \_______/|__/|__/|________/ \_______/
EOF
  echo -e "${RESET}"
  echo -e "${DIM}═══════════════════════════════════════════════════════════════════════════════════════${RESET}"
  echo -e "${MAGENTA}${BOLD}              SentinelOne Agent Manager v3.0 ${RESET}${DIM}| By Root3301${RESET}"
  if [[ -n "$OS_NAME" ]]; then
    echo -e "${DIM}              OS: ${OS_NAME}${OS_VERSION:+ $OS_VERSION} | Package: ${PKG_FAMILY^^} (${PKG_MANAGER})${RESET}"
  fi
  echo -e "${DIM}═══════════════════════════════════════════════════════════════════════════════════════${RESET}\n"
}

# ─── Logging ───────────────────────────────────────────────────────────────────

rotate_logs() {
  if [[ -f "$LOG_FILE" ]]; then
    local size
    size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
    if (( size > 1048576 )); then
      mv "$LOG_FILE" "${LOG_FILE}.$(date '+%Y%m%d%H%M%S')" 2>/dev/null || true
    fi
  fi
}

log_message() {
  local level="$1"; shift
  local msg="$*"

  case "$LOG_LEVEL" in
    ERROR) [[ "$level" == "ERROR" ]] || return 0 ;;
    WARN)  [[ "$level" =~ ^(ERROR|WARN)$ ]] || return 0 ;;
    INFO)  [[ "$level" =~ ^(ERROR|WARN|INFO)$ ]] || return 0 ;;
    DEBUG) ;;
    *) ;;
  esac

  rotate_logs

  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
  echo "[$ts] [$level] $msg" >> "$LOG_FILE"

  case "$level" in
    ERROR) echo -e "${RED}${BOLD}[ERREUR]${RESET} ${RED}$msg${RESET}" ;;
    WARN)  echo -e "${YELLOW}${BOLD}[WARN]${RESET} ${YELLOW}$msg${RESET}" ;;
    INFO)  echo -e "${GREEN}${BOLD}[OK]${RESET} ${GREEN}$msg${RESET}" ;;
    DEBUG) echo -e "${MAGENTA}${BOLD}[DEBUG]${RESET} ${MAGENTA}$msg${RESET}" ;;
    *)     echo -e "${DIM}▸ $msg${RESET}" ;;
  esac
}

check_success_or_log() {
  local rc=$1
  local errmsg="$2"
  local okmsg="$3"

  if (( rc != 0 )); then
    log_message "ERROR" "$errmsg"
    return 1
  else
    [[ -n "$okmsg" ]] && log_message "INFO" "$okmsg"
    return 0
  fi
}

# ─── Fonctions utilitaires ─────────────────────────────────────────────────────

check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${YELLOW}${BOLD}[WARN]${RESET} ${YELLOW}Script lancé sans privilèges root${RESET} ${DIM}- sudo sera utilisé automatiquement${RESET}"
    log_message "WARN" "Le script n'est pas lancé en root. Certaines opérations utiliseront sudo."
    echo
  fi
}

check_s1ctl() {
  if [[ ! -x "$S1CTL" ]]; then
    log_message "ERROR" "sentinelctl introuvable ou non exécutable à l'emplacement : $S1CTL"
    return 1
  fi
  return 0
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

is_url() {
  [[ "$1" =~ ^https?:// ]]
}

cleanup_file() {
  local file_path="$1"
  if [[ -n "$file_path" && -f "$file_path" ]]; then
    rm -f "$file_path"
    log_message "DEBUG" "Fichier temporaire supprimé : $file_path"
  fi
}

# ─── Téléchargement ────────────────────────────────────────────────────────────

download_package_to_temp() {
  local pkg_url="$1"
  local ext="${2:-.pkg}"

  if ! command_exists curl && ! command_exists wget; then
    log_message "ERROR" "curl ou wget est requis pour télécharger un paquet depuis une URL."
    return 1
  fi

  TEMP_FILE="$(mktemp "/tmp/sentinelone-agent-XXXXXX${ext}")"
  log_message "INFO" "Téléchargement du paquet depuis : $pkg_url"
  echo -e "${CYAN}Téléchargement en cours...${RESET}"

  local dl_ok=0
  if command_exists curl; then
    curl -fL --retry 3 --connect-timeout 15 -o "$TEMP_FILE" "$pkg_url" && dl_ok=1
  else
    wget -q --tries=3 --timeout=15 -O "$TEMP_FILE" "$pkg_url" && dl_ok=1
  fi

  if (( dl_ok == 0 )); then
    log_message "ERROR" "Échec du téléchargement depuis $pkg_url"
    cleanup_file "$TEMP_FILE"
    TEMP_FILE=""
    return 1
  fi

  echo "$TEMP_FILE"
}

resolve_package_source() {
  local pkg_source="$1"

  if [[ -z "$pkg_source" ]]; then
    log_message "ERROR" "Source du paquet vide."
    return 1
  fi

  # Extension selon la famille de paquets détectée
  local ext=".pkg"
  [[ "$PKG_FAMILY" == "rpm" ]] && ext=".rpm"
  [[ "$PKG_FAMILY" == "deb" ]] && ext=".deb"

  if is_url "$pkg_source"; then
    local pkg_path
    pkg_path="$(download_package_to_temp "$pkg_source" "$ext")" || return 1
    log_message "INFO" "Fichier téléchargé dans : $pkg_path"
    echo "$pkg_path"
  else
    if [[ ! -f "$pkg_source" ]]; then
      log_message "ERROR" "Le fichier spécifié n'existe pas : $pkg_source"
      return 1
    fi
    TEMP_FILE=""  # fichier local, pas de nettoyage nécessaire
    echo "$pkg_source"
  fi
}

install_package() {
  local pkg_path="$1"
  log_message "INFO" "Installation de l'agent (${PKG_FAMILY:-?}) : $pkg_path"

  case "$PKG_MANAGER" in
    dnf)
      log_message "INFO" "Installation via rpm (--noverify, skip GPG)"
      sudo rpm -ivh --noverify "$pkg_path"
      ;;
    yum)
      log_message "INFO" "Installation via rpm (--noverify, skip GPG)"
      sudo rpm -ivh --noverify "$pkg_path"
      ;;
    rpm)
      log_message "INFO" "Installation via rpm (--noverify, skip GPG)"
      sudo rpm -ivh --noverify "$pkg_path"
      ;;
    apt)
      log_message "INFO" "Installation via apt"
      sudo apt install -y "$pkg_path"
      ;;
    apt-get)
      log_message "INFO" "Installation via apt-get"
      sudo apt-get install -y "$pkg_path"
      ;;
    dpkg)
      log_message "WARN" "Ni apt ni apt-get disponibles, bascule sur dpkg"
      sudo dpkg -i "$pkg_path"
      ;;
    *)
      log_message "ERROR" "Aucun gestionnaire de paquets détecté."
      return 1
      ;;
  esac
}

post_install_agent_start() {
  echo
  echo -e "${BOLD}${CYAN}Démarrage de l'agent...${RESET}"
  log_message "INFO" "Démarrage de l'agent après installation"

  if ! check_s1ctl; then
    log_message "WARN" "sentinelctl non disponible, impossible de démarrer l'agent"
    return 1
  fi

  sudo "$S1CTL" control start
  local start_rc=$?

  if (( start_rc == 0 )); then
    log_message "INFO" "Agent démarré avec succès"
    echo -e "${GREEN}${BOLD}[OK]${RESET} ${GREEN}Agent démarré${RESET}"
    echo
    echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
    echo -e "${BOLD}${CYAN}│${RESET}  ${BOLD}Statut de l'agent${RESET}                                 ${BOLD}${CYAN}│${RESET}"
    echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
    echo
    sudo "$S1CTL" control status
    log_message "INFO" "Statut de l'agent affiché"
    return 0
  fi

  log_message "WARN" "Impossible de démarrer l'agent (rc=$start_rc)"
  echo -e "${YELLOW}${BOLD}[WARN]${RESET} ${YELLOW}L'agent n'a pas pu être démarré automatiquement${RESET}"
  return "$start_rc"
}

perform_install() {
  local pkg_source="$1"
  local cli_mode="${2:-0}"
  local pkg_path=""
  local install_rc=0

  pkg_path="$(resolve_package_source "$pkg_source")" || return 1

  install_package "$pkg_path"
  install_rc=$?

  if ! check_success_or_log "$install_rc" \
    "Échec de l'installation du paquet depuis $pkg_path" \
    "Agent installé avec succès depuis $pkg_path"; then
    return "$install_rc"
  fi

  (( cli_mode == 1 )) && echo "Installation réussie"

  post_install_agent_start || true
  return 0
}

# ─── Actions principales ───────────────────────────────────────────────────────

installer_agent() {
  echo
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│${RESET}  ${BOLD}Installation de l'agent SentinelOne${RESET}             ${BOLD}${CYAN}│${RESET}"
  echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
  echo
  echo -e "${DIM}Famille de paquets détectée : ${BOLD}${PKG_FAMILY:-inconnu}${RESET}${DIM} (${PKG_MANAGER:-?})${RESET}"
  echo
  echo -e "${BOLD}Mode d'installation :${RESET}"
  echo -e "  ${GREEN}[1]${RESET} Fichier local (.rpm ou .deb)"
  echo -e "  ${GREEN}[2]${RESET} URL de téléchargement"
  echo
  read -rp "Votre choix [1-2] : " INSTALL_MODE

  local pkg_source=""

  case "$INSTALL_MODE" in
    1)
      read -rp "Chemin vers le fichier : " pkg_source
      ;;
    2)
      read -rp "URL du paquet : " pkg_source
      if [[ -z "$pkg_source" ]]; then
        log_message "ERROR" "URL vide, opération annulée."
        return 1
      fi
      ;;
    *)
      log_message "ERROR" "Choix invalide."
      return 1
      ;;
  esac

  perform_install "$pkg_source"
  echo
}

ajouter_token() {
  echo
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│${RESET}  ${BOLD}Configuration du token de gestion${RESET}               ${BOLD}${CYAN}│${RESET}"
  echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
  echo
  read -rsp "Entrez le token d'enregistrement : " TOKEN
  echo

  if [[ -z "$TOKEN" ]]; then
    log_message "ERROR" "Le token d'enregistrement est vide, opération annulée."
    return 1
  fi

  check_s1ctl || return 1

  log_message "INFO" "Définition du token de management sur l'agent."
  sudo "$S1CTL" management token set "$TOKEN"
  local rc=$?

  check_success_or_log "$rc" \
    "Erreur lors de la définition du token de management." \
    "Token de gestion défini avec succès."
}

desinstaller_agent() {
  echo
  echo -e "${BOLD}${RED}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${RED}│${RESET}  ${BOLD}Désinstallation de l'agent${RESET}                      ${BOLD}${RED}│${RESET}"
  echo -e "${BOLD}${RED}└─────────────────────────────────────────────────────┘${RESET}"
  echo
  echo -e "${YELLOW}ATTENTION : Cette action va supprimer l'agent SentinelOne du système.${RESET}"
  read -rp "Confirmer la désinstallation (y/N) : " CONFIRM

  if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    log_message "INFO" "Désinstallation annulée par l'utilisateur."
    return 0
  fi

  log_message "INFO" "Tentative de désinstallation de l'agent (paquet : $AGENT_PACKAGE)"

  local rc=0
  case "$PKG_MANAGER" in
    dnf)     sudo dnf remove -y "$AGENT_PACKAGE" ; rc=$? ;;
    yum)     sudo yum remove -y "$AGENT_PACKAGE" ; rc=$? ;;
    rpm)     sudo rpm -e "$AGENT_PACKAGE" ; rc=$? ;;
    apt)     sudo apt remove --purge -y "$AGENT_PACKAGE" ; rc=$? ;;
    apt-get) sudo apt-get remove --purge -y "$AGENT_PACKAGE" ; rc=$? ;;
    dpkg)    sudo dpkg -P "$AGENT_PACKAGE" ; rc=$? ;;
    *)
      log_message "ERROR" "Aucun gestionnaire de paquets détecté pour la désinstallation."
      return 1
      ;;
  esac

  check_success_or_log "$rc" \
    "Échec de la désinstallation du paquet $AGENT_PACKAGE" \
    "Agent SentinelOne désinstallé (paquet $AGENT_PACKAGE)."
}

# ─── Service systemd ───────────────────────────────────────────────────────────

service_status() {
  echo
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│${RESET}  ${BOLD}Statut du service ${SERVICE_NAME}${RESET}               ${BOLD}${CYAN}│${RESET}"
  echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
  echo
  systemctl status "$SERVICE_NAME" --no-pager
  local rc=$?
  log_message "INFO" "Consultation du statut du service $SERVICE_NAME (rc=$rc)"
  echo
  return $rc
}

service_start() {
  echo
  echo -e "${CYAN}Démarrage du service ${BOLD}${SERVICE_NAME}${RESET}${CYAN}...${RESET}"
  log_message "INFO" "Démarrage du service $SERVICE_NAME"
  sudo systemctl start "$SERVICE_NAME"
  local rc=$?
  check_success_or_log "$rc" \
    "Échec du démarrage du service $SERVICE_NAME" \
    "Service $SERVICE_NAME démarré avec succès."
  echo
}

service_stop() {
  echo
  echo -e "${CYAN}Arrêt du service ${BOLD}${SERVICE_NAME}${RESET}${CYAN}...${RESET}"
  log_message "INFO" "Arrêt du service $SERVICE_NAME"
  sudo systemctl stop "$SERVICE_NAME"
  local rc=$?
  check_success_or_log "$rc" \
    "Échec de l'arrêt du service $SERVICE_NAME" \
    "Service $SERVICE_NAME arrêté avec succès."
  echo
}

service_restart() {
  echo
  echo -e "${CYAN}Redémarrage du service ${BOLD}${SERVICE_NAME}${RESET}${CYAN}...${RESET}"
  log_message "INFO" "Redémarrage du service $SERVICE_NAME"
  sudo systemctl restart "$SERVICE_NAME"
  local rc=$?
  check_success_or_log "$rc" \
    "Échec du redémarrage du service $SERVICE_NAME" \
    "Service $SERVICE_NAME redémarré avec succès."
  echo
}

service_enable() {
  echo
  echo -e "${CYAN}Activation du démarrage automatique pour ${BOLD}${SERVICE_NAME}${RESET}${CYAN}...${RESET}"
  log_message "INFO" "Activation auto-démarrage du service $SERVICE_NAME"
  sudo systemctl enable "$SERVICE_NAME"
  local rc=$?
  check_success_or_log "$rc" \
    "Échec de l'activation du service $SERVICE_NAME" \
    "Service $SERVICE_NAME activé au démarrage."
  echo
}

service_disable() {
  echo
  echo -e "${CYAN}Désactivation du démarrage automatique pour ${BOLD}${SERVICE_NAME}${RESET}${CYAN}...${RESET}"
  log_message "INFO" "Désactivation auto-démarrage du service $SERVICE_NAME"
  sudo systemctl disable "$SERVICE_NAME"
  local rc=$?
  check_success_or_log "$rc" \
    "Échec de la désactivation du service $SERVICE_NAME" \
    "Service $SERVICE_NAME désactivé au démarrage."
  echo
}

# ─── Contrôle agent ────────────────────────────────────────────────────────────

verifier_status_agent() {
  echo
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│${RESET}  ${BOLD}Statut de l'agent SentinelOne${RESET}                   ${BOLD}${CYAN}│${RESET}"
  echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
  echo
  check_s1ctl || return 1
  sudo "$S1CTL" control status
  local rc=$?
  log_message "INFO" "Commande 'sentinelctl control status' exécutée (rc=$rc)"
  echo
  return $rc
}

verifier_version_agent() {
  echo
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│${RESET}  ${BOLD}Version de l'agent SentinelOne${RESET}                  ${BOLD}${CYAN}│${RESET}"
  echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
  echo
  check_s1ctl || return 1
  sudo "$S1CTL" version
  local rc=$?
  log_message "INFO" "Commande 'sentinelctl version' exécutée (rc=$rc)"
  echo
  return $rc
}

agent_start() {
  echo
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│${RESET}  ${BOLD}Démarrage de l'agent${RESET}                            ${BOLD}${CYAN}│${RESET}"
  echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
  echo
  check_s1ctl || return 1
  log_message "INFO" "Démarrage de l'agent SentinelOne"
  sudo "$S1CTL" control start
  local rc=$?
  check_success_or_log "$rc" "Échec du démarrage de l'agent" "Agent démarré avec succès"
}

agent_stop() {
  echo
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│${RESET}  ${BOLD}Arrêt de l'agent${RESET}                                ${BOLD}${CYAN}│${RESET}"
  echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
  echo
  check_s1ctl || return 1
  log_message "INFO" "Arrêt de l'agent SentinelOne"
  sudo "$S1CTL" control stop
  local rc=$?
  check_success_or_log "$rc" "Échec de l'arrêt de l'agent" "Agent arrêté avec succès"
}

agent_upgrade() {
  echo
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│${RESET}  ${BOLD}Mise à jour de l'agent${RESET}                          ${BOLD}${CYAN}│${RESET}"
  echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
  echo
  check_s1ctl || return 1
  log_message "INFO" "Mise à jour de l'agent SentinelOne"
  sudo "$S1CTL" control upgrade
  local rc=$?
  check_success_or_log "$rc" "Échec de la mise à jour de l'agent" "Agent mis à jour avec succès"
}

# ─── Logs ─────────────────────────────────────────────────────────────────────

afficher_logs() {
  echo
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│${RESET}  ${BOLD}Consultation des logs${RESET}                           ${BOLD}${CYAN}│${RESET}"
  echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
  echo
  echo -e "${BOLD}${MAGENTA}▶ Logs du script S1 Manager${RESET}"
  if [[ -f "$LOG_FILE" ]]; then
    echo -e "${DIM}Fichier : $LOG_FILE${RESET}"
    echo -e "${DIM}─────────────────────────────────────────────────────${RESET}"
    tail -n 50 "$LOG_FILE"
  else
    echo -e "${RED}Aucun fichier de log trouvé à $LOG_FILE${RESET}"
  fi

  echo
  echo -e "${BOLD}${MAGENTA}▶ Logs systemd (${SERVICE_NAME})${RESET}"
  echo -e "${DIM}─────────────────────────────────────────────────────${RESET}"
  journalctl -u "$SERVICE_NAME" -n 30 --no-pager 2>/dev/null || \
    echo -e "${YELLOW}Pas de logs systemd disponibles.${RESET}"
}

show_agent_log() {
  echo
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│${RESET}  ${BOLD}Logs de l'agent${RESET}                                 ${BOLD}${CYAN}│${RESET}"
  echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
  echo
  check_s1ctl || return 1
  sudo "$S1CTL" log
  local rc=$?
  log_message "INFO" "Consultation des logs de l'agent (rc=$rc)"
  echo
  return $rc
}

# ─── Health Check ──────────────────────────────────────────────────────────────

health_check() {
  echo
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│${RESET}  ${BOLD}Health Check Complet${RESET}                            ${BOLD}${CYAN}│${RESET}"
  echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
  echo
  log_message "INFO" "Exécution du health check SentinelOne."

  local overall_status="OK"

  # 0. Informations système
  echo -e "${BOLD}${BLUE}➤ Informations système${RESET}"
  echo -e "   OS      : ${GREEN}${OS_NAME:-inconnu}${OS_VERSION:+ $OS_VERSION}${RESET}"
  echo -e "   Famille : ${GREEN}${PKG_FAMILY:-inconnu}${RESET} (${PKG_MANAGER:-?})"

  # 1. Binaire sentinelctl
  echo
  echo -e "${BOLD}${BLUE}➤ Vérifications système${RESET}"
  if check_s1ctl 2>/dev/null; then
    echo -e "   [OK] sentinelctl : ${GREEN}${BOLD}DISPONIBLE${RESET} ${DIM}($S1CTL)${RESET}"
  else
    echo -e "   [ERREUR] sentinelctl : ${RED}${BOLD}INTROUVABLE${RESET} ${DIM}($S1CTL)${RESET}"
    overall_status="WARN"
  fi

  # 2. Service systemd
  echo
  echo -e "${BOLD}${BLUE}➤ État du service systemd${RESET}"
  if systemctl is-enabled "$SERVICE_NAME" &>/dev/null; then
    echo -e "   [OK] Auto-démarrage : ${GREEN}${BOLD}ACTIVÉ${RESET}"
  else
    echo -e "   [WARN] Auto-démarrage : ${YELLOW}${BOLD}DÉSACTIVÉ${RESET}"
    overall_status="WARN"
  fi

  if systemctl is-active "$SERVICE_NAME" &>/dev/null; then
    echo -e "   [OK] État actuel : ${GREEN}${BOLD}EN COURS D'EXÉCUTION${RESET}"
  else
    echo -e "   [ERREUR] État actuel : ${RED}${BOLD}ARRÊTÉ${RESET}"
    overall_status="WARN"
  fi

  # 3. Statut agent
  if check_s1ctl 2>/dev/null; then
    echo
    echo -e "${BOLD}${BLUE}➤ Statut de l'agent (sentinelctl)${RESET}"
    echo -e "${DIM}─────────────────────────────────────────────────────${RESET}"
    sudo "$S1CTL" control status || {
      echo -e "${RED}[ERREUR] Erreur lors de l'exécution de control status${RESET}"
      overall_status="WARN"
    }

    # 4. Version agent
    echo
    echo -e "${BOLD}${BLUE}➤ Version de l'agent${RESET}"
    echo -e "${DIM}─────────────────────────────────────────────────────${RESET}"
    sudo "$S1CTL" version || {
      echo -e "${RED}[ERREUR] Impossible de récupérer la version de l'agent${RESET}"
      overall_status="WARN"
    }
  fi

  # 5. Logs systemd récents
  echo
  echo -e "${BOLD}${BLUE}➤ Logs systemd récents${RESET}"
  echo -e "${DIM}─────────────────────────────────────────────────────${RESET}"
  journalctl -u "$SERVICE_NAME" -n 20 --no-pager 2>/dev/null || \
    echo -e "${YELLOW}Pas de logs systemd disponibles.${RESET}"

  echo
  echo -e "${DIM}═════════════════════════════════════════════════════${RESET}"
  if [[ "$overall_status" == "OK" ]]; then
    echo -e "${BOLD}${GREEN}[OK] Health Check global : TOUS LES TESTS RÉUSSIS${RESET}"
    log_message "INFO" "Health Check OK."
    return 0
  else
    echo -e "${BOLD}${YELLOW}[WARN] Health Check global : AVERTISSEMENTS DÉTECTÉS${RESET}"
    log_message "WARN" "Health Check avec avertissements."
    return 1
  fi
}

# ─── Opérations de sécurité ────────────────────────────────────────────────────

scan_start() {
  echo
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│${RESET}  ${BOLD}Démarrage d'un scan${RESET}                             ${BOLD}${CYAN}│${RESET}"
  echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
  echo
  check_s1ctl || return 1
  log_message "INFO" "Démarrage d'un scan de disque"
  sudo "$S1CTL" scan start
  local rc=$?
  check_success_or_log "$rc" "Échec du démarrage du scan" "Scan démarré avec succès"
}

scan_abort() {
  echo
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│${RESET}  ${BOLD}Arrêt du scan en cours${RESET}                          ${BOLD}${CYAN}│${RESET}"
  echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
  echo
  check_s1ctl || return 1
  log_message "INFO" "Arrêt du scan en cours"
  sudo "$S1CTL" scan abort
  local rc=$?
  check_success_or_log "$rc" "Échec de l'arrêt du scan" "Scan arrêté avec succès"
}

scan_status() {
  echo
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│${RESET}  ${BOLD}Statut du scan${RESET}                                  ${BOLD}${CYAN}│${RESET}"
  echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
  echo
  check_s1ctl || return 1
  sudo "$S1CTL" scan status
  local rc=$?
  log_message "INFO" "Consultation du statut du scan (rc=$rc)"
  echo
  return $rc
}

policy_status() {
  echo
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│${RESET}  ${BOLD}Statut des policies${RESET}                             ${BOLD}${CYAN}│${RESET}"
  echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
  echo
  check_s1ctl || return 1
  sudo "$S1CTL" policy status
  local rc=$?
  log_message "INFO" "Consultation du statut des policies (rc=$rc)"
  echo
  return $rc
}

quarantine_list() {
  echo
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│${RESET}  ${BOLD}Liste des fichiers en quarantaine${RESET}               ${BOLD}${CYAN}│${RESET}"
  echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
  echo
  check_s1ctl || return 1

  echo -e "${BOLD}Options disponibles :${RESET}"
  echo -e "  ${GREEN}[1]${RESET} Tous les fichiers"
  echo -e "  ${GREEN}[2]${RESET} Par groupe"
  echo
  read -rp "Votre choix [1-2] : " QUAR_CHOICE

  case "$QUAR_CHOICE" in
    1)
      log_message "INFO" "Liste de tous les fichiers en quarantaine"
      sudo "$S1CTL" quarantine list all
      ;;
    2)
      read -rp "Nom du groupe : " GROUP_NAME
      log_message "INFO" "Liste des fichiers en quarantaine pour le groupe : $GROUP_NAME"
      sudo "$S1CTL" quarantine list "$GROUP_NAME"
      ;;
    *)
      log_message "ERROR" "Choix invalide"
      return 1
      ;;
  esac

  local rc=$?
  echo
  return $rc
}

firewall_operations() {
  echo
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│${RESET}  ${BOLD}Opérations firewall${RESET}                             ${BOLD}${CYAN}│${RESET}"
  echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
  echo
  check_s1ctl || return 1
  sudo "$S1CTL" fw
  local rc=$?
  log_message "INFO" "Opérations firewall (rc=$rc)"
  echo
  return $rc
}

# ─── Configuration avancée ─────────────────────────────────────────────────────

asset_management() {
  echo
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│${RESET}  ${BOLD}Gestion des assets${RESET}                              ${BOLD}${CYAN}│${RESET}"
  echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
  echo
  check_s1ctl || return 1
  sudo "$S1CTL" asset
  local rc=$?
  log_message "INFO" "Gestion des assets (rc=$rc)"
  echo
  return $rc
}

engines_operations() {
  echo
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│${RESET}  ${BOLD}Opérations sur les engines${RESET}                      ${BOLD}${CYAN}│${RESET}"
  echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
  echo
  check_s1ctl || return 1
  sudo "$S1CTL" engines
  local rc=$?
  log_message "INFO" "Opérations sur les engines (rc=$rc)"
  echo
  return $rc
}

management_detector() {
  echo
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│${RESET}  ${BOLD}Détection de l'agent${RESET}                            ${BOLD}${CYAN}│${RESET}"
  echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
  echo
  check_s1ctl || return 1
  sudo "$S1CTL" detector
  local rc=$?
  log_message "INFO" "Détection de l'agent (rc=$rc)"
  echo
  return $rc
}

# ─── Installation des outils ───────────────────────────────────────────────────

install_sentinelonectl() {
  local target="/usr/local/bin/sentinelonectl"
  local source="$SCRIPT_DIR/sentinelonectl"

  echo
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│${RESET}  ${BOLD}Installation de sentinelonectl${RESET}                  ${BOLD}${CYAN}│${RESET}"
  echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
  echo

  if [[ ! -f "$source" ]]; then
    log_message "ERROR" "Fichier sentinelonectl introuvable dans $SCRIPT_DIR"
    echo -e "${YELLOW}Assurez-vous que le fichier sentinelonectl est dans le même répertoire que ce script.${RESET}"
    return 1
  fi

  sudo cp "$source" "$target"
  sudo chmod +x "$target"
  local rc=$?

  check_success_or_log "$rc" \
    "Échec de l'installation de sentinelonectl vers $target" \
    "sentinelonectl installé dans $target"

  if (( rc == 0 )); then
    echo -e "${GREEN}Utilisez maintenant : ${BOLD}sentinelonectl help${RESET}"
  fi
}

# ─── Mode CLI ──────────────────────────────────────────────────────────────────

print_help() {
  echo -e "${BOLD}${CYAN}"
  cat << "EOF"
  /$$$$$$                        /$$     /$$                     /$$ /$$
 /$$__  $$                      | $$    |__/                    | $$|__/
| $$  \__/  /$$$$$$  /$$$$$$$  /$$$$$$   /$$ /$$$$$$$   /$$$$$$ | $$ /$$ /$$$$$$$$  /$$$$$$
|  $$$$$$  /$$__  $$| $$__  $$|_  $$_/  | $$| $$__  $$ /$$__  $$| $$| $$|____ /$$/ /$$__  $$
 \____  $$| $$$$$$$$| $$  \ $$  | $$    | $$| $$  \ $$| $$$$$$$$| $$| $$   /$$$$/ | $$$$$$$$
 /$$  \ $$| $$_____/| $$  | $$  | $$ /$$| $$| $$  | $$| $$_____/| $$| $$  /$$__/  | $$_____/
|  $$$$$$/|  $$$$$$$| $$  | $$  |  $$$$/| $$| $$  | $$|  $$$$$$$| $$| $$ /$$$$$$$$|  $$$$$$$
 \______/  \_______/|__/  |__/   \___/  |__/|__/  |__/ \_______/|__/|__/|________/ \_______/
EOF
  echo -e "${RESET}"
  echo -e "${DIM}═══════════════════════════════════════════════════════════════════════════════════════${RESET}"
  echo -e "${BOLD}Usage :${RESET} $0 ${DIM}[OPTION]${RESET}\n"
  echo -e "${BOLD}${BLUE}Options (mode CLI non-interactif) :${RESET}"
  echo -e "  ${GREEN}--install${RESET} <chemin|url>        Installer l'agent (RPM/DEB, local ou URL)"
  echo -e "  ${GREEN}--set-token${RESET} <token>           Définir le token de management"
  echo -e "  ${GREEN}--status${RESET}                      Afficher statut service + agent"
  echo -e "  ${GREEN}--health-check${RESET}                Lancer un health check complet"
  echo -e "  ${GREEN}--version${RESET}                     Afficher la version de l'agent"
  echo -e "  ${GREEN}--install-tools${RESET}               Installer sentinelonectl dans /usr/local/bin"
  echo -e "  ${GREEN}--help${RESET}, ${GREEN}-h${RESET}                    Afficher cette aide"
  echo
  echo -e "${DIM}Sans option, le menu interactif est affiché.${RESET}\n"
}

handle_cli() {
  case "$1" in
    --install)
      shift
      local pkg_source="${1:-}"
      if [[ -z "$pkg_source" ]]; then
        echo "Erreur : chemin ou URL du paquet manquant."
        exit 1
      fi
      log_message "INFO" "Mode CLI : installation demandée ($pkg_source)"
      perform_install "$pkg_source" 1
      exit $?
      ;;
    --set-token)
      shift
      local token_val="${1:-}"
      if [[ -z "$token_val" ]]; then
        echo "Erreur : token manquant."
        exit 1
      fi
      log_message "INFO" "Mode CLI : définition du token."
      check_s1ctl || exit 1
      sudo "$S1CTL" management token set "$token_val"
      exit $?
      ;;
    --status)
      log_message "INFO" "Mode CLI : statut global."
      service_status
      verifier_status_agent
      exit 0
      ;;
    --health-check)
      log_message "INFO" "Mode CLI : health check."
      health_check
      exit $?
      ;;
    --version)
      log_message "INFO" "Mode CLI : version agent."
      verifier_version_agent
      exit $?
      ;;
    --install-tools)
      log_message "INFO" "Mode CLI : installation de sentinelonectl."
      install_sentinelonectl
      exit $?
      ;;
    --help|-h)
      print_help
      exit 0
      ;;
    *)
      echo "Option inconnue : $1"
      print_help
      exit 1
      ;;
  esac
}

# ─── Menus interactifs ─────────────────────────────────────────────────────────

afficher_menu() {
  echo -e "${BOLD}${BLUE}╔═════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${CYAN}${BOLD}MENU PRINCIPAL${RESET}                                        ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}╠═════════════════════════════════════════════════════════╣${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[1]${RESET} Installation & Configuration                    ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[2]${RESET} Contrôle de l'agent                             ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[3]${RESET} Opérations de sécurité                          ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[4]${RESET} Monitoring & Diagnostic                         ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[5]${RESET} Configuration avancée                           ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[6]${RESET} Gestion du service systemd                      ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[7]${RESET} Installer sentinelonectl (CLI système)          ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}╠═════════════════════════════════════════════════════════╣${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${YELLOW}[0]${RESET} Quitter                                         ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}╚═════════════════════════════════════════════════════════╝${RESET}"
  echo
  echo -e -n "${CYAN}${BOLD}>${RESET} Votre choix ${DIM}[0-7]${RESET} : "
  read -r CHOIX
}

menu_installation() {
  clear
  banner
  echo -e "${BOLD}${BLUE}╔═════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${CYAN}${BOLD}INSTALLATION & CONFIGURATION${RESET}                         ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}╠═════════════════════════════════════════════════════════╣${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[1]${RESET} Installer l'agent (RPM/DEB auto-détecté)       ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[2]${RESET} Configurer le token de management              ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[3]${RESET} Mettre à jour l'agent                           ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${RED}║${RESET}  ${RED}[4]${RESET} Désinstaller l'agent                            ${BOLD}${RED}║${RESET}"
  echo -e "${BOLD}${BLUE}╠═════════════════════════════════════════════════════════╣${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${YELLOW}[0]${RESET} Retour au menu principal                       ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}╚═════════════════════════════════════════════════════════╝${RESET}"
  echo
  echo -e -n "${CYAN}${BOLD}>${RESET} Votre choix ${DIM}[0-4]${RESET} : "
  read -r SUBCHOIX

  case "$SUBCHOIX" in
    1) installer_agent ;;
    2) ajouter_token ;;
    3) agent_upgrade ;;
    4) desinstaller_agent ;;
    0) return ;;
    *) log_message "WARN" "Choix invalide : $SUBCHOIX" ;;
  esac

  echo
  echo -e "${CYAN}Appuyez sur ${BOLD}Entrée${RESET}${CYAN} pour continuer...${RESET}"
  read -r
}

menu_controle_agent() {
  clear
  banner
  echo -e "${BOLD}${BLUE}╔═════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${CYAN}${BOLD}CONTRÔLE DE L'AGENT${RESET}                                  ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}╠═════════════════════════════════════════════════════════╣${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[1]${RESET} Démarrer l'agent                                ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[2]${RESET} Arrêter l'agent                                 ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[3]${RESET} Statut de l'agent                               ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[4]${RESET} Version de l'agent                              ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[5]${RESET} Détection de l'agent                            ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}╠═════════════════════════════════════════════════════════╣${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${YELLOW}[0]${RESET} Retour au menu principal                       ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}╚═════════════════════════════════════════════════════════╝${RESET}"
  echo
  echo -e -n "${CYAN}${BOLD}>${RESET} Votre choix ${DIM}[0-5]${RESET} : "
  read -r SUBCHOIX

  case "$SUBCHOIX" in
    1) agent_start ;;
    2) agent_stop ;;
    3) verifier_status_agent ;;
    4) verifier_version_agent ;;
    5) management_detector ;;
    0) return ;;
    *) log_message "WARN" "Choix invalide : $SUBCHOIX" ;;
  esac

  echo
  echo -e "${CYAN}Appuyez sur ${BOLD}Entrée${RESET}${CYAN} pour continuer...${RESET}"
  read -r
}

menu_securite() {
  clear
  banner
  echo -e "${BOLD}${BLUE}╔═════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${CYAN}${BOLD}OPÉRATIONS DE SÉCURITÉ${RESET}                               ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}╠═════════════════════════════════════════════════════════╣${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[1]${RESET} Démarrer un scan                                ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[2]${RESET} Arrêter le scan en cours                        ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[3]${RESET} Statut du scan                                  ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[4]${RESET} Statut des policies                             ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[5]${RESET} Fichiers en quarantaine                         ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[6]${RESET} Opérations firewall                             ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}╠═════════════════════════════════════════════════════════╣${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${YELLOW}[0]${RESET} Retour au menu principal                       ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}╚═════════════════════════════════════════════════════════╝${RESET}"
  echo
  echo -e -n "${CYAN}${BOLD}>${RESET} Votre choix ${DIM}[0-6]${RESET} : "
  read -r SUBCHOIX

  case "$SUBCHOIX" in
    1) scan_start ;;
    2) scan_abort ;;
    3) scan_status ;;
    4) policy_status ;;
    5) quarantine_list ;;
    6) firewall_operations ;;
    0) return ;;
    *) log_message "WARN" "Choix invalide : $SUBCHOIX" ;;
  esac

  echo
  echo -e "${CYAN}Appuyez sur ${BOLD}Entrée${RESET}${CYAN} pour continuer...${RESET}"
  read -r
}

menu_monitoring() {
  clear
  banner
  echo -e "${BOLD}${BLUE}╔═════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${CYAN}${BOLD}MONITORING & DIAGNOSTIC${RESET}                              ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}╠═════════════════════════════════════════════════════════╣${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[1]${RESET} Health Check complet                            ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[2]${RESET} Logs de l'agent                                 ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[3]${RESET} Logs du script & systemd                        ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[4]${RESET} Statut complet (service + agent)                ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}╠═════════════════════════════════════════════════════════╣${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${YELLOW}[0]${RESET} Retour au menu principal                       ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}╚═════════════════════════════════════════════════════════╝${RESET}"
  echo
  echo -e -n "${CYAN}${BOLD}>${RESET} Votre choix ${DIM}[0-4]${RESET} : "
  read -r SUBCHOIX

  case "$SUBCHOIX" in
    1) health_check ;;
    2) show_agent_log ;;
    3) afficher_logs ;;
    4) service_status && verifier_status_agent ;;
    0) return ;;
    *) log_message "WARN" "Choix invalide : $SUBCHOIX" ;;
  esac

  echo
  echo -e "${CYAN}Appuyez sur ${BOLD}Entrée${RESET}${CYAN} pour continuer...${RESET}"
  read -r
}

menu_avance() {
  clear
  banner
  echo -e "${BOLD}${BLUE}╔═════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${CYAN}${BOLD}CONFIGURATION AVANCÉE${RESET}                                ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}╠═════════════════════════════════════════════════════════╣${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[1]${RESET} Gestion des assets                              ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[2]${RESET} Opérations sur les engines                      ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}╠═════════════════════════════════════════════════════════╣${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${YELLOW}[0]${RESET} Retour au menu principal                       ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}╚═════════════════════════════════════════════════════════╝${RESET}"
  echo
  echo -e -n "${CYAN}${BOLD}>${RESET} Votre choix ${DIM}[0-2]${RESET} : "
  read -r SUBCHOIX

  case "$SUBCHOIX" in
    1) asset_management ;;
    2) engines_operations ;;
    0) return ;;
    *) log_message "WARN" "Choix invalide : $SUBCHOIX" ;;
  esac

  echo
  echo -e "${CYAN}Appuyez sur ${BOLD}Entrée${RESET}${CYAN} pour continuer...${RESET}"
  read -r
}

menu_service() {
  clear
  banner
  echo -e "${BOLD}${BLUE}╔═════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${CYAN}${BOLD}GESTION DU SERVICE SYSTEMD${RESET}                           ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}╠═════════════════════════════════════════════════════════╣${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[1]${RESET} Statut du service                               ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[2]${RESET} Démarrer le service                             ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[3]${RESET} Arrêter le service                              ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[4]${RESET} Redémarrer le service                           ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[5]${RESET} Activer au démarrage système                    ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[6]${RESET} Désactiver au démarrage système                 ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}╠═════════════════════════════════════════════════════════╣${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${YELLOW}[0]${RESET} Retour au menu principal                       ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}╚═════════════════════════════════════════════════════════╝${RESET}"
  echo
  echo -e -n "${CYAN}${BOLD}>${RESET} Votre choix ${DIM}[0-6]${RESET} : "
  read -r SUBCHOIX

  case "$SUBCHOIX" in
    1) service_status ;;
    2) service_start ;;
    3) service_stop ;;
    4) service_restart ;;
    5) service_enable ;;
    6) service_disable ;;
    0) return ;;
    *) log_message "WARN" "Choix invalide : $SUBCHOIX" ;;
  esac

  echo
  echo -e "${CYAN}Appuyez sur ${BOLD}Entrée${RESET}${CYAN} pour continuer...${RESET}"
  read -r
}

# ─── Main ──────────────────────────────────────────────────────────────────────

detect_os
check_root

# Si des arguments sont fournis → mode CLI
if (( $# > 0 )); then
  handle_cli "$@"
fi

# Mode interactif
while true; do
  banner
  afficher_menu

  case "$CHOIX" in
    1) menu_installation ;;
    2) menu_controle_agent ;;
    3) menu_securite ;;
    4) menu_monitoring ;;
    5) menu_avance ;;
    6) menu_service ;;
    7)
      install_sentinelonectl
      echo
      echo -e "${CYAN}Appuyez sur ${BOLD}Entrée${RESET}${CYAN} pour continuer...${RESET}"
      read -r
      ;;
    0)
      echo
      echo -e "${BOLD}${GREEN}Merci d'avoir utilisé Sentinelize v3.0 !${RESET}"
      echo -e "${DIM}À bientôt !${RESET}\n"
      log_message "INFO" "Script terminé par l'utilisateur."
      exit 0
      ;;
    *)
      echo
      echo -e "${BOLD}${RED}Choix invalide !${RESET} Merci de saisir un numéro entre ${BOLD}0${RESET} et ${BOLD}7${RESET}."
      log_message "WARN" "Choix invalide dans le menu : $CHOIX"
      echo
      echo -e "${CYAN}Appuyez sur ${BOLD}Entrée${RESET}${CYAN} pour continuer...${RESET}"
      read -r
      ;;
  esac
done
