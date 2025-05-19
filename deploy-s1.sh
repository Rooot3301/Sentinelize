#!/bin/bash

# ────────────────────────────────────────────────
# SentinelOne Deployment Manager - CLI Edition
# Par : Romain Varene 🛡️
# Date : 2025-05-19
# ────────────────────────────────────────────────

S1CTL="/opt/sentinelone/bin/sentinelctl"

# === COULEURS ===
GREEN="\e[32m"
RED="\e[31m"
CYAN="\e[36m"
YELLOW="\e[33m"
RESET="\e[0m"

# === ASCII ART ===
function banner() {
  clear
  echo -e "${CYAN}"
  echo "╔════════════════════════════════════════════════════════╗"
  echo "║              🛡️ SENTINELONE MANAGER CLI 🛡️              ║"
  echo "║          Par Romain Varene - Technicien Cyber          ║"
  echo "╚════════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

# === LOG FUNCTIONS ===
function log_info() {
  echo -e "${GREEN}[INFO]${RESET} $1"
}

function log_error() {
  echo -e "${RED}[ERREUR]${RESET} $1"
}

function check_success() {
  if [ $? -ne 0 ]; then
    log_error "$1"
    exit 1
  fi
}

# === ACTIONS ===

function installer_agent() {
  echo -e "\n📦 ${YELLOW}Installation de l'agent SentinelOne${RESET}"
  read -p "👉 Chemin vers le fichier RPM (.rpm) : " RPM_PATH

  if [ ! -f "$RPM_PATH" ]; then
    log_error "Le fichier spécifié n'existe pas : $RPM_PATH"
    return
  fi

  sudo rpm -i "$RPM_PATH"
  check_success "Échec de l'installation du paquet."

  log_info "✅ Agent installé avec succès."
}

function ajouter_token() {
  echo -e "\n🔐 ${YELLOW}Ajout du token de gestion${RESET}"
  read -p "👉 Entrez le token d'enregistrement : " TOKEN

  if [ -z "$TOKEN" ]; then
    log_error "Le token ne peut pas être vide."
    return
  fi

  sudo $S1CTL management token set "$TOKEN"
  check_success "Erreur lors de la définition du token."

  log_info "✅ Token ajouté avec succès."
}

function verifier_status() {
  echo -e "\n🔎 ${YELLOW}Statut de l'agent${RESET}"
  sudo $S1CTL control status
  echo
}

function verifier_version() {
  echo -e "\n📄 ${YELLOW}Version de l'agent${RESET}"
  sudo $S1CTL version
  echo
}

# === MENU PRINCIPAL ===

function afficher_menu() {
  echo -e "${CYAN}Que souhaitez-vous faire ?${RESET}"
  echo "1️⃣  Installer un agent SentinelOne"
  echo "2️⃣  Ajouter un token de gestion"
  echo "3️⃣  Vérifier le statut de l'agent"
  echo "4️⃣  Vérifier la version de l'agent"
  echo "5️⃣  Quitter"
  echo
  read -p "👉 Choix [1-5] : " CHOIX
}

# === BOUCLE PRINCIPALE ===

while true; do
  banner
  afficher_menu

  case $CHOIX in
    1) installer_agent ;;
    2) ajouter_token ;;
    3) verifier_status ;;
    4) verifier_version ;;
    5) echo -e "${CYAN}À bientôt, merci d’avoir utilisé SentinelOne Manager 🛡️${RESET}"; exit 0 ;;
    *) log_error "Choix invalide. Veuillez entrer un numéro entre 1 et 5." ;;
  esac

  echo -e "\n🔁 Appuyez sur Entrée pour retourner au menu principal..."
  read
done
