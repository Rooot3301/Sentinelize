#!/bin/bash
#
# SentinelOne Agent Manager - RPM Edition
# Author: Root3301
# Version: 2.0
#

set -o pipefail

# Configuration par défaut

S1CTL_DEFAULT="/opt/sentinelone/bin/sentinelctl"
SERVICE_NAME_DEFAULT="sentinelone"          # À ADAPTER au vrai nom du service
AGENT_PACKAGE_DEFAULT="sentinelone-agent"   # À ADAPTER au vrai nom du paquet RPM
LOG_FILE_DEFAULT="/var/log/s1-manager.log"
LOG_LEVEL_DEFAULT="INFO"                    # ERROR | WARN | INFO | DEBUG

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

# Couleurs

GREEN="\e[32m"
RED="\e[31m"
CYAN="\e[36m"
YELLOW="\e[33m"
MAGENTA="\e[35m"
BLUE="\e[34m"
BOLD="\e[1m"
DIM="\e[2m"
RESET="\e[0m"

# Banner

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
  echo -e "${MAGENTA}${BOLD}              SentinelOne Agent Manager v2.0 ${RESET}${DIM}| By Root3301${RESET}"
  echo -e "${DIM}═══════════════════════════════════════════════════════════════════════════════════════${RESET}\n"
}

# Gestion des logs

rotate_logs() {
  # Rotation si > 1 Mo
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

  # Filtrage selon LOG_LEVEL
  case "$LOG_LEVEL" in
    ERROR)
      [[ "$level" == "ERROR" ]] || return 0
      ;;
    WARN)
      [[ "$level" =~ ^(ERROR|WARN)$ ]] || return 0
      ;;
    INFO)
      [[ "$level" =~ ^(ERROR|WARN|INFO)$ ]] || return 0
      ;;
    DEBUG)
      ;;
    *)
      ;;
  esac

  rotate_logs

  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
  echo "[$ts] [$level] $msg" >> "$LOG_FILE"

  # Console + couleurs
  case "$level" in
    ERROR) echo -e "${RED}${BOLD}[ERREUR]${RESET} ${RED}$msg${RESET}" ;;
    WARN)  echo -e "${YELLOW}${BOLD}[WARN]${RESET} ${YELLOW}$msg${RESET}" ;;
    INFO)  echo -e "${GREEN}${BOLD}[OK]${RESET} ${GREEN}$msg${RESET}" ;;
    DEBUG) echo -e "${MAGENTA}${BOLD}[DEBUG]${RESET} ${MAGENTA}$msg${RESET}" ;;
    *)     echo -e "${DIM}▸ $msg${RESET}" ;;
  esac
}

display_message() {
  local color="$1"; shift
  echo -e "${color}$*${RESET}"
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

# Fonctions utilitaires

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

# Actions principales

installer_agent_rpm() {
  echo
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│${RESET}  ${BOLD}Installation de l'agent SentinelOne${RESET}             ${BOLD}${CYAN}│${RESET}"
  echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
  echo
  echo -e "${BOLD}Choisissez le mode d'installation :${RESET}"
  echo -e "  ${GREEN}[1]${RESET} Fichier local (chemin)"
  echo -e "  ${GREEN}[2]${RESET} URL de téléchargement"
  echo
  read -rp "Votre choix [1-2] : " INSTALL_MODE

  local RPM_PATH=""
  local TEMP_FILE=""

  case "$INSTALL_MODE" in
    1)
      read -rp "Chemin vers le fichier RPM (.rpm) : " RPM_PATH
      if [[ ! -f "$RPM_PATH" ]]; then
        log_message "ERROR" "Le fichier spécifié n'existe pas : $RPM_PATH"
        return 1
      fi
      ;;
    2)
      read -rp "URL du fichier RPM : " RPM_URL
      if [[ -z "$RPM_URL" ]]; then
        log_message "ERROR" "URL vide, opération annulée."
        return 1
      fi

      TEMP_FILE="/tmp/sentinelone-agent-$(date +%s).rpm"
      log_message "INFO" "Téléchargement du RPM depuis : $RPM_URL"
      echo -e "${CYAN}Téléchargement en cours...${RESET}"

      if ! curl -fL -o "$TEMP_FILE" "$RPM_URL"; then
        log_message "ERROR" "Échec du téléchargement depuis $RPM_URL"
        [[ -f "$TEMP_FILE" ]] && rm -f "$TEMP_FILE"
        return 1
      fi

      RPM_PATH="$TEMP_FILE"
      log_message "INFO" "Fichier téléchargé dans : $RPM_PATH"
      ;;
    *)
      log_message "ERROR" "Choix invalide."
      return 1
      ;;
  esac

  log_message "INFO" "Installation de l'agent via RPM : $RPM_PATH"
  sudo rpm -i "$RPM_PATH"
  local rc=$?

  if [[ -n "$TEMP_FILE" ]] && [[ -f "$TEMP_FILE" ]]; then
    rm -f "$TEMP_FILE"
    log_message "DEBUG" "Fichier temporaire supprimé : $TEMP_FILE"
  fi

  if ! check_success_or_log "$rc" \
    "Échec de l'installation du paquet depuis $RPM_PATH" \
    "Agent installé avec succès depuis $RPM_PATH"; then
    return 1
  fi

  # Démarrage de l'agent après installation
  echo
  echo -e "${BOLD}${CYAN}Démarrage de l'agent...${RESET}"
  log_message "INFO" "Démarrage de l'agent après installation"

  if check_s1ctl; then
    sudo "$S1CTL" control start
    local start_rc=$?

    if (( start_rc == 0 )); then
      log_message "INFO" "Agent démarré avec succès"
      echo -e "${GREEN}${BOLD}[OK]${RESET} ${GREEN}Agent démarré${RESET}"

      # Affichage du statut de l'agent
      echo
      echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
      echo -e "${BOLD}${CYAN}│${RESET}  ${BOLD}Statut de l'agent${RESET}                                   ${BOLD}${CYAN}│${RESET}"
      echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
      echo
      sudo "$S1CTL" control status
      log_message "INFO" "Statut de l'agent affiché"
    else
      log_message "WARN" "Impossible de démarrer l'agent (rc=$start_rc)"
      echo -e "${YELLOW}${BOLD}[WARN]${RESET} ${YELLOW}L'agent n'a pas pu être démarré automatiquement${RESET}"
    fi
  else
    log_message "WARN" "sentinelctl non disponible, impossible de démarrer l'agent"
  fi

  echo
}

ajouter_token() {
  echo
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│${RESET}  ${BOLD}Configuration du token de gestion${RESET}               ${BOLD}${CYAN}│${RESET}"
  echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
  echo
  read -rp "Entrez le token d'enregistrement : " TOKEN

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

service_status() {
  echo
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│${RESET}  ${BOLD}Statut du service $SERVICE_NAME${RESET}                  ${BOLD}${CYAN}│${RESET}"
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
  echo -e "${CYAN}Démarrage du service ${BOLD}$SERVICE_NAME${RESET}${CYAN}...${RESET}"
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
  echo -e "${CYAN}Arrêt du service ${BOLD}$SERVICE_NAME${RESET}${CYAN}...${RESET}"
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
  echo -e "${CYAN}Redémarrage du service ${BOLD}$SERVICE_NAME${RESET}${CYAN}...${RESET}"
  log_message "INFO" "Redémarrage du service $SERVICE_NAME"
  sudo systemctl restart "$SERVICE_NAME"
  local rc=$?
  check_success_or_log "$rc" \
    "Échec du redémarrage du service $SERVICE_NAME" \
    "Service $SERVICE_NAME redémarré avec succès."
  echo
}

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
  sudo rpm -e "$AGENT_PACKAGE"
  local rc=$?

  check_success_or_log "$rc" \
    "Échec de la désinstallation du paquet $AGENT_PACKAGE" \
    "Agent SentinelOne désinstallé (paquet $AGENT_PACKAGE)."
}

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
  echo -e "${BOLD}${MAGENTA}▶ Logs systemd ($SERVICE_NAME)${RESET}"
  echo -e "${DIM}─────────────────────────────────────────────────────${RESET}"
  journalctl -u "$SERVICE_NAME" -n 30 --no-pager 2>/dev/null || echo -e "${YELLOW}Pas de logs systemd disponibles.${RESET}"
}

health_check() {
  echo
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│${RESET}  ${BOLD}Health Check Complet${RESET}                            ${BOLD}${CYAN}│${RESET}"
  echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────┘${RESET}"
  echo
  log_message "INFO" "Exécution du health check SentinelOne."

  local overall_status="OK"

  # 1. binaire sentinelctl
  echo -e "${BOLD}${BLUE}➤ Vérifications système${RESET}"
  if check_s1ctl; then
    echo -e "   [OK] sentinelctl : ${GREEN}${BOLD}DISPONIBLE${RESET} ${DIM}($S1CTL)${RESET}"
  else
    echo -e "   [ERREUR] sentinelctl : ${RED}${BOLD}INTROUVABLE${RESET} ${DIM}($S1CTL)${RESET}"
    overall_status="WARN"
  fi

  # 2. Service systemd
  echo
  echo -e "${BOLD}${BLUE}➤ État du service systemd${RESET}"
  if systemctl is-enabled "$SERVICE_NAME" &>/dev/null; then
    echo -e "   [OK] Activation auto-démarrage : ${GREEN}${BOLD}ACTIVÉ${RESET}"
  else
    echo -e "   [WARN] Activation auto-démarrage : ${YELLOW}${BOLD}DÉSACTIVÉ${RESET}"
    overall_status="WARN"
  fi

  if systemctl is-active "$SERVICE_NAME" &>/dev/null; then
    echo -e "   [OK] État actuel : ${GREEN}${BOLD}EN COURS D'EXÉCUTION${RESET}"
  else
    echo -e "   [ERREUR] État actuel : ${RED}${BOLD}ARRÊTÉ${RESET}"
    overall_status="WARN"
  fi

  # 3. Status agent
  if check_s1ctl; then
    echo
    echo -e "${BOLD}${BLUE}➤ Statut de l'agent (sentinelctl)${RESET}"
    echo -e "${DIM}─────────────────────────────────────────────────────${RESET}"
    if ! sudo "$S1CTL" control status; then
      echo -e "${RED}[ERREUR] Erreur lors de l'exécution de control status${RESET}"
      overall_status="WARN"
    fi
  fi

  # 4. Version agent
  if check_s1ctl; then
    echo
    echo -e "${BOLD}${BLUE}➤ Version de l'agent${RESET}"
    echo -e "${DIM}─────────────────────────────────────────────────────${RESET}"
    if ! sudo "$S1CTL" version; then
      echo -e "${RED}[ERREUR] Impossible de récupérer la version de l'agent${RESET}"
      overall_status="WARN"
    fi
  fi

  echo
  echo -e "${BOLD}${BLUE}➤ Logs systemd récents${RESET}"
  echo -e "${DIM}─────────────────────────────────────────────────────${RESET}"
  journalctl -u "$SERVICE_NAME" -n 20 --no-pager 2>/dev/null || echo -e "${YELLOW}Pas de logs systemd disponibles.${RESET}"

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

# Fonctions SentinelCTL

# Scan operations
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

# Policy operations
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

# Quarantine operations
quarantine_list() {
  echo
  echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│${RESET}  ${BOLD}Liste des fichiers en quarantaine${RESET}              ${BOLD}${CYAN}│${RESET}"
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

# Agent control operations
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

# Log operations
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

# Asset management
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

# Engines operations
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

# Firewall operations
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

# Management operations
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

# Mode CLI (non-interactif)

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
  echo -e "  ${GREEN}--install-rpm${RESET} <chemin|url>   Installer l'agent (fichier local ou URL)"
  echo -e "  ${GREEN}--set-token${RESET} <token>          Définir le token de management"
  echo -e "  ${GREEN}--status${RESET}                     Afficher statut service + agent"
  echo -e "  ${GREEN}--health-check${RESET}               Lancer un health check complet"
  echo -e "  ${GREEN}--version${RESET}                    Afficher la version de l'agent"
  echo -e "  ${GREEN}--help${RESET}, ${GREEN}-h${RESET}                   Afficher cette aide"
  echo
  echo -e "${DIM}Sans option, un menu interactif est affiché.${RESET}\n"
}

handle_cli() {
  case "$1" in
    --install-rpm)
      shift
      RPM_SOURCE="$1"
      if [[ -z "$RPM_SOURCE" ]]; then
        echo "Erreur : chemin ou URL RPM manquant."
        exit 1
      fi

      local RPM_PATH=""
      local TEMP_FILE=""

      if [[ "$RPM_SOURCE" =~ ^https?:// ]]; then
        log_message "INFO" "Mode CLI : installation RPM depuis URL ($RPM_SOURCE)"
        TEMP_FILE="/tmp/sentinelone-agent-$(date +%s).rpm"
        echo "Téléchargement en cours..."

        if ! curl -fL -o "$TEMP_FILE" "$RPM_SOURCE"; then
          log_message "ERROR" "Échec du téléchargement depuis $RPM_SOURCE"
          [[ -f "$TEMP_FILE" ]] && rm -f "$TEMP_FILE"
          exit 1
        fi

        RPM_PATH="$TEMP_FILE"
        log_message "INFO" "Fichier téléchargé : $RPM_PATH"
      else
        log_message "INFO" "Mode CLI : installation RPM depuis fichier local ($RPM_SOURCE)"
        if [[ ! -f "$RPM_SOURCE" ]]; then
          log_message "ERROR" "RPM introuvable : $RPM_SOURCE"
          exit 1
        fi
        RPM_PATH="$RPM_SOURCE"
      fi

      sudo rpm -i "$RPM_PATH"
      local rc=$?

      if [[ -n "$TEMP_FILE" ]] && [[ -f "$TEMP_FILE" ]]; then
        rm -f "$TEMP_FILE"
        log_message "DEBUG" "Fichier temporaire supprimé"
      fi

      if (( rc != 0 )); then
        log_message "ERROR" "Échec de l'installation"
        exit $rc
      fi

      log_message "INFO" "Agent installé avec succès"
      echo "Installation réussie"

      # Démarrage de l'agent après installation
      echo
      echo "Démarrage de l'agent..."
      log_message "INFO" "Démarrage de l'agent après installation (mode CLI)"

      if check_s1ctl; then
        sudo "$S1CTL" control start
        local start_rc=$?

        if (( start_rc == 0 )); then
          log_message "INFO" "Agent démarré avec succès"
          echo "Agent démarré avec succès"

          # Affichage du statut de l'agent
          echo
          echo "=== Statut de l'agent ==="
          sudo "$S1CTL" control status
          log_message "INFO" "Statut de l'agent affiché"
          exit 0
        else
          log_message "WARN" "Impossible de démarrer l'agent (rc=$start_rc)"
          echo "AVERTISSEMENT : L'agent n'a pas pu être démarré automatiquement"
          exit $start_rc
        fi
      else
        log_message "WARN" "sentinelctl non disponible"
        echo "AVERTISSEMENT : sentinelctl non disponible, impossible de démarrer l'agent"
        exit 1
      fi
      ;;
    --set-token)
      shift
      TOKEN="$1"
      if [[ -z "$TOKEN" ]]; then
        echo "Erreur : token manquant."
        exit 1
      fi
      log_message "INFO" "Mode CLI : définition du token."
      check_s1ctl || exit 1
      sudo "$S1CTL" management token set "$TOKEN"
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

# Menu interactif

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
  echo -e "${BOLD}${BLUE}╠═════════════════════════════════════════════════════════╣${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${YELLOW}[0]${RESET} Quitter                                         ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}╚═════════════════════════════════════════════════════════╝${RESET}"
  echo
  echo -e -n "${CYAN}${BOLD}>${RESET} Votre choix ${DIM}[0-6]${RESET} : "
  read -r CHOIX
}

menu_installation() {
  clear
  banner
  echo -e "${BOLD}${BLUE}╔═════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${CYAN}${BOLD}INSTALLATION & CONFIGURATION${RESET}                         ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}╠═════════════════════════════════════════════════════════╣${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[1]${RESET} Installer l'agent SentinelOne (RPM)            ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[2]${RESET} Configurer le token de management              ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[3]${RESET} Mettre à jour l'agent                           ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${RED}[4]${RESET} Désinstaller l'agent                            ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}╠═════════════════════════════════════════════════════════╣${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${YELLOW}[0]${RESET} Retour au menu principal                       ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}╚═════════════════════════════════════════════════════════╝${RESET}"
  echo
  echo -e -n "${CYAN}${BOLD}>${RESET} Votre choix ${DIM}[0-4]${RESET} : "
  read -r SUBCHOIX

  case "$SUBCHOIX" in
    1) installer_agent_rpm ;;
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
  echo -e "${BOLD}${BLUE}║${RESET}  ${GREEN}[4]${RESET} Statut complet (service + agent)               ${BOLD}${BLUE}║${RESET}"
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
  echo -e "${BOLD}${BLUE}╠═════════════════════════════════════════════════════════╣${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${YELLOW}[0]${RESET} Retour au menu principal                       ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}╚═════════════════════════════════════════════════════════╝${RESET}"
  echo
  echo -e -n "${CYAN}${BOLD}>${RESET} Votre choix ${DIM}[0-4]${RESET} : "
  read -r SUBCHOIX

  case "$SUBCHOIX" in
    1) service_status ;;
    2) service_start ;;
    3) service_stop ;;
    4) service_restart ;;
    0) return ;;
    *) log_message "WARN" "Choix invalide : $SUBCHOIX" ;;
  esac

  echo
  echo -e "${CYAN}Appuyez sur ${BOLD}Entrée${RESET}${CYAN} pour continuer...${RESET}"
  read -r
}

# Main

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
    0)
      echo
      echo -e "${BOLD}${GREEN}Merci d'avoir utilisé Sentinelize v2.0 !${RESET}"
      echo -e "${DIM}À bientôt !${RESET}\n"
      log_message "INFO" "Script terminé par l'utilisateur."
      exit 0
      ;;
    *)
      echo
      echo -e "${BOLD}${RED}Choix invalide !${RESET} Merci de saisir un numéro entre ${BOLD}0${RESET} et ${BOLD}6${RESET}."
      log_message "WARN" "Choix invalide dans le menu : $CHOIX"
      echo
      echo -e "${CYAN}Appuyez sur ${BOLD}Entrée${RESET}${CYAN} pour continuer...${RESET}"
      read -r
      ;;
  esac
done
