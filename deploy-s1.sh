#!/bin/bash

# ────────────────────────────────────────────────
# SentinelOne Deployment Manager
# Par : Romain Varene 🛡️
# Date : 2025-05-19
# ────────────────────────────────────────────────

# === CONFIG ===
S1CTL="/opt/sentinelone/bin/sentinelctl"

# === ASCII ART ===
function display_banner() {
  clear
  echo -e "\e[36m"
  echo "  ███████╗███████╗███╗   ██╗████████╗██╗███████╗██╗     ███████╗"
  echo "  ██╔════╝██╔════╝████╗  ██║╚══██╔══╝██║██╔════╝██║     ██╔════╝"
  echo "  ███████╗█████╗  ██╔██╗ ██║   ██║   ██║█████╗  ██║     █████╗  "
  echo "  ╚════██║██╔══╝  ██║╚██╗██║   ██║   ██║██╔══╝  ██║     ██╔══╝  "
  echo "  ███████║███████╗██║ ╚████║   ██║   ██║███████╗███████╗███████╗"
  echo "  ╚══════╝╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚═╝╚══════╝╚══════╝╚══════╝"
  echo "                 Déploiement SentinelOne - by Romain 🛡️"
  echo -e "\e[0m"
}

# === LOGGING ===
function log_info() {
  echo -e "\e[32m[INFO]\e[0m $1"
}

function log_error() {
  echo -e "\e[31m[ERREUR]\e[0m $1"
}

function check_success() {
  if [ $? -ne 0 ]; then
    log_error "$1"
    exit 1
  fi
}

# === FONCTIONS PRINCIPALES ===

function installer_agent() {
  RPM_PATH=$(dialog --stdout --title "Chemin vers le fichier RPM" --inputbox "Entrez le chemin vers le fichier .rpm :" 10 60)
  if [ ! -f "$RPM_PATH" ]; then
    log_error "Fichier introuvable : $RPM_PATH"
    return
  fi

  log_info "Installation du paquet..."
  sudo rpm -i "$RPM_PATH"
  check_success "Échec de l'installation du paquet."
  log_info "✅ Agent installé."
  read -p "Appuyez sur Entrée pour continuer..."
}

function ajouter_token() {
  TOKEN=$(dialog --stdout --title "Token SentinelOne" --inputbox "Entrez le token de gestion :" 10 60)
  if [ -z "$TOKEN" ]; then
    log_error "Token vide."
    return
  fi

  sudo $S1CTL management token set "$TOKEN"
  check_success "Erreur lors de la définition du token."
  log_info "✅ Token défini avec succès."
  read -p "Appuyez sur Entrée pour continuer..."
}

function verifier_status() {
  log_info "État de l'agent SentinelOne :"
  sudo $S1CTL control status
  read -p "Appuyez sur Entrée pour continuer..."
}

function verifier_version() {
  log_info "Version de l'agent SentinelOne :"
  sudo $S1CTL version
  read -p "Appuyez sur Entrée pour continuer..."
}

# === MAIN MENU ===
function menu() {
  while true; do
    CHOICE=$(dialog --stdout --clear --title "🛡️ SentinelOne Manager - Menu" \
      --menu "Choisissez une option :" 15 60 5 \
      1 "🚀 Installer un agent" \
      2 "🔐 Ajouter un token" \
      3 "🔎 Vérifier le status" \
      4 "📄 Vérifier la version" \
      5 "❌ Quitter")

    case $CHOICE in
      1) installer_agent ;;
      2) ajouter_token ;;
      3) verifier_status ;;
      4) verifier_version ;;
      5) clear; exit 0 ;;
      *) log_error "Option invalide." ;;
    esac
  done
}

# === LANCEMENT ===
display_banner
menu
