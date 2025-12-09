#!/bin/bash
# ────────────────────────────────────────────────
# SentinelOne Agent Manager - RPM Edition
# Auteur : Root3301
# Version : v2.0
# ────────────────────────────────────────────────

set -o pipefail

############################################
#             CONFIG PAR DÉFAUT            #
############################################

S1CTL_DEFAULT="/opt/sentinelone/bin/sentinelctl"
SERVICE_NAME_DEFAULT="sentinelone"          # ⚠️ À ADAPTER au vrai nom du service
AGENT_PACKAGE_DEFAULT="sentinelone-agent"   # ⚠️ À ADAPTER au vrai nom du paquet RPM
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

############################################
#                 COULEURS                 #
############################################

GREEN="\e[32m"
RED="\e[31m"
CYAN="\e[36m"
YELLOW="\e[33m"
MAGENTA="\e[35m"
RESET="\e[0m"

############################################
#                 BANNER                   #
############################################

banner() {
  clear
  echo -e "${CYAN}"
  echo "╔════════════════════════════════════════════════════════╗"
  echo "║             SENTINELONE AGENT MANAGER - RPM           ║"
  echo "║v2.0                      By Root3301                  ║"
  echo "╚════════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

############################################
#          GESTION DES LOGS                #
############################################

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

  rotate_logs()

  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
  echo "[$ts] [$level] $msg" >> "$LOG_FILE"

  # Console + couleurs
  case "$level" in
    ERROR) echo -e "${RED}[ERREUR]${RESET} $msg" ;;
    WARN)  echo -e "${YELLOW}[WARN]${RESET} $msg" ;;
    INFO)  echo -e "${GREEN}[INFO]${RESET} $msg" ;;
    DEBUG) echo -e "${MAGENTA}[DEBUG]${RESET} $msg" ;;
    *)     echo "[LOG] $msg" ;;
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

############################################
#          FONCTIONS UTILITAIRES           #
############################################

check_root() {
  if [[ $EUID -ne 0 ]]; then
    log_message "WARN" "Le script n'est pas lancé en root. Certaines opérations utiliseront sudo."
  fi
}

check_s1ctl() {
  if [[ ! -x "$S1CTL" ]]; then
    log_message "ERROR" "sentinelctl introuvable ou non exécutable à l'emplacement : $S1CTL"
    return 1
  fi
  return 0
}

############################################
#           ACTIONS PRINCIPALES           #
############################################

installer_agent_rpm() {
  display_message "$YELLOW" "\nInstallation de l'agent SentinelOne (RPM)"
  read -rp "Chemin vers le fichier RPM (.rpm) : " RPM_PATH

  if [[ ! -f "$RPM_PATH" ]]; then
    log_message "ERROR" "Le fichier spécifié n'existe pas : $RPM_PATH"
    return 1
  fi

  log_message "INFO" "Installation de l'agent via RPM : $RPM_PATH"
  sudo rpm -i "$RPM_PATH"
  local rc=$?

  check_success_or_log "$rc" \
    "Échec de l'installation du paquet depuis $RPM_PATH" \
    "Agent installé avec succès depuis $RPM_PATH"
}

ajouter_token() {
  display_message "$YELLOW" "\nAjout du token de gestion SentinelOne"
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
  display_message "$YELLOW" "\nStatut du service SentinelOne ($SERVICE_NAME)"
  systemctl status "$SERVICE_NAME" --no-pager
  local rc=$?
  log_message "INFO" "Consultation du statut du service $SERVICE_NAME (rc=$rc)"
  echo
  return $rc
}

service_start() {
  log_message "INFO" "Démarrage du service $SERVICE_NAME"
  sudo systemctl start "$SERVICE_NAME"
  local rc=$?
  check_success_or_log "$rc" \
    "Échec du démarrage du service $SERVICE_NAME" \
    "Service $SERVICE_NAME démarré avec succès."
}

service_stop() {
  log_message "INFO" "Arrêt du service $SERVICE_NAME"
  sudo systemctl stop "$SERVICE_NAME"
  local rc=$?
  check_success_or_log "$rc" \
    "Échec de l'arrêt du service $SERVICE_NAME" \
    "Service $SERVICE_NAME arrêté avec succès."
}

service_restart() {
  log_message "INFO" "Redémarrage du service $SERVICE_NAME"
  sudo systemctl restart "$SERVICE_NAME"
  local rc=$?
  check_success_or_log "$rc" \
    "Échec du redémarrage du service $SERVICE_NAME" \
    "Service $SERVICE_NAME redémarré avec succès."
}

verifier_status_agent() {
  display_message "$YELLOW" "\nStatut de l'agent (sentinelctl control status)"
  check_s1ctl || return 1
  sudo "$S1CTL" control status
  local rc=$?
  log_message "INFO" "Commande 'sentinelctl control status' exécutée (rc=$rc)"
  echo
  return $rc
}

verifier_version_agent() {
  display_message "$YELLOW" "\nVersion de l'agent SentinelOne"
  check_s1ctl || return 1
  sudo "$S1CTL" version
  local rc=$?
  log_message "INFO" "Commande 'sentinelctl version' exécutée (rc=$rc)"
  echo
  return $rc
}

desinstaller_agent() {
  display_message "$YELLOW" "\nDésinstallation de l'agent SentinelOne"
  read -rp "Confirmer la désinstallation de l'agent (y/N) : " CONFIRM

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
  display_message "$YELLOW" "\nLogs du SentinelOne Agent Manager"
  if [[ -f "$LOG_FILE" ]]; then
    echo -e "${CYAN}Fichier : $LOG_FILE${RESET}"
    tail -n 50 "$LOG_FILE"
  else
    echo -e "${RED}Aucun fichier de log trouvé à $LOG_FILE${RESET}"
  fi

  echo -e "\n${CYAN}Derniers logs systemd du service $SERVICE_NAME${RESET}"
  journalctl -u "$SERVICE_NAME" -n 30 --no-pager 2>/dev/null || echo "Pas de logs systemd disponibles."
}

health_check() {
  display_message "$YELLOW" "\nHealth Check SentinelOne - Résumé"
  log_message "INFO" "Exécution du health check SentinelOne."

  local overall_status="OK"

  # 1. binaire sentinelctl
  if check_s1ctl; then
    echo -e " - sentinelctl : ${GREEN}OK${RESET} ($S1CTL)"
  else
    echo -e " - sentinelctl : ${RED}KO${RESET} ($S1CTL introuvable)"
    overall_status="WARN"
  fi

  # 2. Service systemd
  if systemctl is-enabled "$SERVICE_NAME" &>/dev/null; then
    echo -e " - Service $SERVICE_NAME : ${GREEN}activé${RESET}"
  else
    echo -e " - Service $SERVICE_NAME : ${YELLOW}non activé${RESET}"
    overall_status="WARN"
  fi

  if systemctl is-active "$SERVICE_NAME" &>/dev/null; then
    echo -e " - État runtime : ${GREEN}actif${RESET}"
  else
    echo -e " - État runtime : ${RED}inactif${RESET}"
    overall_status="WARN"
  fi

  # 3. Status agent
  if check_s1ctl; then
    echo -e "\n${CYAN}▶ sentinelctl control status${RESET}"
    if ! sudo "$S1CTL" control status; then
      echo -e "${RED}Erreur lors de l'exécution de control status${RESET}"
      overall_status="WARN"
    fi
  fi

  # 4. Version agent
  if check_s1ctl; then
    echo -e "\n${CYAN}▶ sentinelctl version${RESET}"
    if ! sudo "$S1CTL" version; then
      echo -e "${RED}Impossible de récupérer la version de l'agent${RESET}"
      overall_status="WARN"
    fi
  fi

  echo -e "\n${CYAN}▶ Derniers logs systemd ($SERVICE_NAME)${RESET}"
  journalctl -u "$SERVICE_NAME" -n 20 --no-pager 2>/dev/null || echo "Pas de logs systemd disponibles."

  echo
  if [[ "$overall_status" == "OK" ]]; then
    display_message "$GREEN" "Health Check global : OK"
    log_message "INFO" "Health Check OK."
    return 0
  else
    display_message "$YELLOW" "Health Check global : AVERTISSEMENTS (voir détails ci-dessus)."
    log_message "WARN" "Health Check avec avertissements."
    return 1
  fi
}

############################################
#          MODE CLI (NON-INTERACTIF)       #
############################################

print_help() {
  cat <<EOF
Usage : $0 [OPTION]

Options (mode non-interactif) :
  --install-rpm <chemin>   Installer l'agent depuis un fichier RPM
  --set-token <token>      Définir le token de management
  --status                 Afficher statut service + agent
  --health-check           Lancer un health check complet
  --version                Afficher la version de l'agent
  --help                   Afficher cette aide

Sans option, un menu interactif est affiché.
EOF
}

handle_cli() {
  case "$1" in
    --install-rpm)
      shift
      RPM_PATH="$1"
      if [[ -z "$RPM_PATH" ]]; then
        echo "Erreur : chemin RPM manquant."
        exit 1
      fi
      log_message "INFO" "Mode CLI : installation RPM ($RPM_PATH)"
      if [[ ! -f "$RPM_PATH" ]]; then
        log_message "ERROR" "RPM introuvable : $RPM_PATH"
        exit 1
      fi
      sudo rpm -i "$RPM_PATH"
      exit $?
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

############################################
#             MENU INTERACTIF              #
############################################

afficher_menu() {
  echo -e "${CYAN}Que souhaitez-vous faire ?${RESET}"
  echo "1 - Installer un agent SentinelOne (RPM local)"
  echo "2 - Ajouter / modifier le token de gestion"
  echo "3 - Statut du service ($SERVICE_NAME)"
  echo "4 - Démarrer le service"
  echo "5 - Arrêter le service"
  echo "6 - Redémarrer le service"
  echo "7 - Statut de l'agent (sentinelctl control status)"
  echo "8 - Version de l'agent"
  echo "9 - Désinstaller l'agent"
  echo "10 - Afficher les logs (script + systemd)"
  echo "11 - Health Check complet"
  echo "12 - Quitter"
  echo
  read -rp "Choix [1-12] : " CHOIX
}

############################################
#                MAIN                      #
############################################

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
    1) installer_agent_rpm ;;
    2) ajouter_token ;;
    3) service_status ;;
    4) service_start ;;
    5) service_stop ;;
    6) service_restart ;;
    7) verifier_status_agent ;;
    8) verifier_version_agent ;;
    9) desinstaller_agent ;;
    10) afficher_logs ;;
    11) health_check ;;
    12)
      display_message "$GREEN" "Merci d'avoir utilisé SentinelOne Agent Manager v2.0."
      log_message "INFO" "Script terminé par l'utilisateur."
      exit 0
      ;;
    *)
      display_message "$RED" "⚠️ Choix invalide. Merci de saisir un numéro entre 1 et 12."
      log_message "WARN" "Choix invalide dans le menu : $CHOIX"
      ;;
  esac

  echo -e "\nAppuyez sur Entrée pour revenir au menu principal..."
  read -r
done


