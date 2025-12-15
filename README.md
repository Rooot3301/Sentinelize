# SentinelOne Agent Manager v2.0

Script Bash avancé pour la gestion complète de l'agent SentinelOne sur Linux avec une interface organisée en sous-menus.

---

## Table des matières

- [Présentation](#présentation)
- [Prérequis](#prérequis)
- [Installation](#installation)
- [Configuration](#configuration)
- [Utilisation](#utilisation)
  - [Mode Interactif](#mode-interactif)
  - [Mode CLI](#mode-cli)
- [Fonctionnalités](#fonctionnalités)
- [Exemples](#exemples)
- [Logs](#logs)
- [Sécurité](#sécurité)
- [Licence](#licence)

---

## Présentation

SentinelOne Agent Manager v2.0 est un outil de gestion complet pour l'agent SentinelOne sur Linux. Il offre une interface interactive organisée en menus et sous-menus, ainsi qu'un mode CLI pour l'automatisation.

### Fonctionnalités principales

#### Installation & Configuration
- Installer l'agent depuis un fichier RPM local ou une URL
- Configurer le token de management
- Mettre à jour l'agent
- Désinstaller l'agent

#### Contrôle de l'agent
- Démarrer/Arrêter l'agent
- Vérifier le statut et la version
- Détection de l'agent

#### Opérations de sécurité
- Lancer, arrêter et surveiller des scans
- Consulter le statut des policies
- Gérer les fichiers en quarantaine
- Opérations firewall

#### Monitoring & Diagnostic
- Health check complet
- Consultation des logs (agent, script, systemd)
- Statut détaillé du service

#### Configuration avancée
- Gestion des assets
- Opérations sur les engines

#### Gestion du service systemd
- Contrôle complet du service (start, stop, restart, status)

---

## Prérequis

- Distribution Linux avec accès `sudo`
- Bash shell
- `curl` pour le téléchargement depuis URL
- Agent SentinelOne installable (fichier RPM ou URL)
- Token de gestion SentinelOne (pour l'enregistrement)

---

## Installation

```bash
# 1. Télécharger le script
wget https://votre-repo.com/deploy-s1.sh
# ou
curl -O https://votre-repo.com/deploy-s1.sh

# 2. Rendre le script exécutable
chmod +x deploy-s1.sh

# 3. (Optionnel) Créer un fichier de configuration
cp .env.example .env
nano .env
```

---

## Configuration

Le script utilise un fichier `.env` optionnel pour la configuration. Créez ce fichier à partir de l'exemple fourni :

```bash
cp .env.example .env
```

### Variables configurables

```bash
# Chemin vers l'exécutable sentinelctl
S1CTL="/opt/sentinelone/bin/sentinelctl"

# Nom du service systemd
SERVICE_NAME="sentinelone"

# Nom du paquet RPM de l'agent
AGENT_PACKAGE="sentinelone-agent"

# Fichier de log du script
LOG_FILE="/var/log/s1-manager.log"

# Niveau de log (ERROR | WARN | INFO | DEBUG)
LOG_LEVEL="INFO"
```

**Note** : Si le fichier `.env` n'existe pas, le script utilisera les valeurs par défaut.

---

## Utilisation

### Mode Interactif

Lancez le script sans arguments pour accéder au menu interactif :

```bash
./deploy-s1.sh
```

Le menu principal affiche les catégories suivantes :

```
╔═════════════════════════════════════════════════════════╗
║  MENU PRINCIPAL                                         ║
╠═════════════════════════════════════════════════════════╣
║  [1] Installation & Configuration                       ║
║  [2] Contrôle de l'agent                                ║
║  [3] Opérations de sécurité                             ║
║  [4] Monitoring & Diagnostic                            ║
║  [5] Configuration avancée                              ║
║  [6] Gestion du service systemd                         ║
╠═════════════════════════════════════════════════════════╣
║  [0] Quitter                                            ║
╚═════════════════════════════════════════════════════════╝
```

Chaque option mène à un sous-menu détaillé avec les opérations spécifiques.

### Mode CLI

Le script supporte également un mode ligne de commande pour l'automatisation :

```bash
# Afficher l'aide
./deploy-s1.sh --help

# Installer l'agent depuis un fichier local
sudo ./deploy-s1.sh --install-rpm /path/to/agent.rpm

# Installer l'agent depuis une URL
sudo ./deploy-s1.sh --install-rpm https://example.com/agent.rpm

# Configurer le token de management
sudo ./deploy-s1.sh --set-token "YOUR_TOKEN_HERE"

# Vérifier le statut
./deploy-s1.sh --status

# Health check complet
./deploy-s1.sh --health-check

# Afficher la version de l'agent
./deploy-s1.sh --version
```

---

## Fonctionnalités

### 1. Installation & Configuration

**Installer l'agent**
- Depuis un fichier RPM local
- Depuis une URL (téléchargement automatique avec curl)

**Configurer le token**
- Configuration du token de management pour l'enregistrement auprès de la console SentinelOne

**Mettre à jour l'agent**
- Utilise `sentinelctl control upgrade`

**Désinstaller l'agent**
- Désinstallation complète avec confirmation

### 2. Contrôle de l'agent

- `sentinelctl control start` - Démarrer l'agent
- `sentinelctl control stop` - Arrêter l'agent
- `sentinelctl control status` - Statut de l'agent
- `sentinelctl version` - Version de l'agent
- `sentinelctl detector` - Détection de l'agent

### 3. Opérations de sécurité

**Scans**
- `sentinelctl scan start` - Démarrer un scan
- `sentinelctl scan abort` - Arrêter le scan en cours
- `sentinelctl scan status` - Statut du scan

**Policies**
- `sentinelctl policy status` - Statut des policies

**Quarantaine**
- `sentinelctl quarantine list all` - Liste tous les fichiers en quarantaine
- `sentinelctl quarantine list <group>` - Liste par groupe

**Firewall**
- `sentinelctl fw` - Opérations firewall

### 4. Monitoring & Diagnostic

**Health Check**
- Vérification du binaire sentinelctl
- État du service systemd
- Statut de l'agent
- Version de l'agent
- Logs récents

**Logs**
- Logs du script (s1-manager.log)
- Logs de l'agent (via sentinelctl log)
- Logs systemd (journalctl)

### 5. Configuration avancée

- `sentinelctl asset` - Gestion des assets
- `sentinelctl engines` - Opérations sur les engines

### 6. Gestion du service systemd

- `systemctl status sentinelone` - Statut du service
- `systemctl start sentinelone` - Démarrer le service
- `systemctl stop sentinelone` - Arrêter le service
- `systemctl restart sentinelone` - Redémarrer le service

---

## Exemples

### Installation complète depuis une URL

```bash
# Lancer le script
sudo ./deploy-s1.sh

# Sélectionner [1] Installation & Configuration
# Sélectionner [1] Installer l'agent SentinelOne (RPM)
# Sélectionner [2] URL de téléchargement
# Entrer l'URL : https://example.com/sentinelone-agent.rpm

# Retour au menu principal
# Sélectionner [1] Installation & Configuration
# Sélectionner [2] Configurer le token de management
# Entrer le token d'enregistrement
```

### Lancer un scan de sécurité

```bash
sudo ./deploy-s1.sh

# Sélectionner [3] Opérations de sécurité
# Sélectionner [1] Démarrer un scan
```

### Health check complet

```bash
sudo ./deploy-s1.sh --health-check
```

Sortie exemple :
```
➤ Vérifications système
   [OK] sentinelctl : DISPONIBLE (/opt/sentinelone/bin/sentinelctl)

➤ État du service systemd
   [OK] Activation auto-démarrage : ACTIVÉ
   [OK] État actuel : EN COURS D'EXÉCUTION

➤ Statut de l'agent (sentinelctl)
─────────────────────────────────────────────────────
[détails du statut...]

➤ Version de l'agent
─────────────────────────────────────────────────────
Agent version: 23.x.x.xxx

[OK] Health Check global : TOUS LES TESTS RÉUSSIS
```

### Automatisation avec le mode CLI

```bash
#!/bin/bash

# Script d'installation automatique
AGENT_URL="https://example.com/sentinelone-agent.rpm"
TOKEN="votre-token-ici"

# Installation
sudo ./deploy-s1.sh --install-rpm "$AGENT_URL"

# Configuration du token
sudo ./deploy-s1.sh --set-token "$TOKEN"

# Vérification
./deploy-s1.sh --health-check
```

---

## Logs

### Logs du script

Le script génère des logs dans `/var/log/s1-manager.log` (configurable via `.env`).

**Caractéristiques** :
- Rotation automatique des logs (> 1 Mo)
- Niveaux de log : ERROR, WARN, INFO, DEBUG
- Horodatage de chaque événement
- Format : `[YYYY-MM-DD HH:MM:SS] [LEVEL] message`

**Consulter les logs** :
```bash
# 50 dernières lignes
tail -n 50 /var/log/s1-manager.log

# Suivi en temps réel
tail -f /var/log/s1-manager.log

# Via le menu interactif
./deploy-s1.sh
# [4] Monitoring & Diagnostic > [3] Logs du script & systemd
```

### Logs de l'agent

Consultez les logs de l'agent via :
- Menu interactif : [4] Monitoring & Diagnostic > [2] Logs de l'agent
- Commande directe : `sudo sentinelctl log`

### Logs systemd

```bash
# Logs du service
journalctl -u sentinelone -n 50

# Suivi en temps réel
journalctl -u sentinelone -f
```

---

## Sécurité

### Bonnes pratiques

1. **Privilèges sudo**
   - Le script nécessite des privilèges sudo pour les opérations critiques
   - Vérifiez toujours la source du script avant exécution

2. **Validation des fichiers**
   - Le script vérifie l'existence des fichiers RPM avant installation
   - Validation des URLs avant téléchargement

3. **Nettoyage automatique**
   - Les fichiers temporaires sont supprimés après téléchargement
   - Pas de données sensibles stockées dans les logs

4. **Gestion des tokens**
   - Les tokens ne sont jamais loggés
   - Utilisez des variables d'environnement pour les scripts automatisés

### Recommandations

- Conservez le fichier `.env` avec des permissions restrictives :
  ```bash
  chmod 600 .env
  ```

- Utilisez un utilisateur de service dédié pour les déploiements automatisés

- Auditez régulièrement les logs pour détecter les anomalies

---

## Gestion des erreurs

Le script implémente une gestion complète des erreurs :

- **Codes de retour** : Chaque fonction retourne un code de retour approprié
- **Messages clairs** : Messages d'erreur colorés et explicites
- **Validation des paramètres** : Vérification avant exécution
- **Logs détaillés** : Tous les événements sont journalisés

Format des messages :
- `[OK]` - Opération réussie (vert)
- `[WARN]` - Avertissement (jaune)
- `[ERREUR]` - Erreur (rouge)
- `[DEBUG]` - Information de debug (magenta)

---

## Licence

Ce script est proposé à titre éducatif et professionnel.

**Conditions** :
- Libre de modification et distribution
- Attribution de l'auteur original requise
- Aucune garantie fournie

---

## Contribution

Les contributions sont les bienvenues !

**Comment contribuer** :
- Signaler des bugs via les issues
- Proposer des améliorations
- Soumettre des pull requests

**Guidelines** :
- Respecter le style de code existant
- Documenter les nouvelles fonctionnalités
- Tester avant de soumettre

---

## Support

**Documentation officielle SentinelOne** :
- [Documentation sentinelctl](https://docs.sentinelone.com/)

**Auteur** : Root3301
**Version** : 2.0
**Date** : Décembre 2025

---

**Développé par Root3301**
