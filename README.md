# SentinelOne Agent Manager v3.0

Script Bash avancé pour la gestion complète de l'agent SentinelOne sur Linux, avec support **multi-OS** (RPM & DEB), interface interactive en sous-menus et CLI système `sentinelonectl`.

---

## Table des matières

- [Présentation](#présentation)
- [Prérequis](#prérequis)
- [Installation](#installation)
- [Configuration](#configuration)
- [Utilisation](#utilisation)
  - [Mode Interactif](#mode-interactif)
  - [Mode CLI (deploy-s1.sh)](#mode-cli-deploy-s1sh)
  - [sentinelonectl](#sentinelonectl)
- [Fonctionnalités](#fonctionnalités)
- [Exemples](#exemples)
- [Logs](#logs)
- [Sécurité](#sécurité)
- [Licence](#licence)

---

## Présentation

SentinelOne Agent Manager v3.0 est un outil de gestion complet pour l'agent SentinelOne sur Linux. Il supporte automatiquement les distributions basées sur RPM (RHEL, Rocky, AlmaLinux, CentOS, Fedora) et DEB (Ubuntu, Debian), détecte le gestionnaire de paquets disponible et expose toutes les opérations via un menu interactif ou un CLI système.

### Nouveautés v3.0

- **Support multi-OS** : détection automatique RPM/DEB, fallback `wget` si `curl` absent
- **sentinelonectl** : CLI installable système (`/usr/local/bin`) pour gérer l'agent depuis n'importe où
- **Installation sans validation GPG** : `rpm -ivh --noverify` pour éviter les erreurs de signature
- **Robustesse** : nettoyage automatique des fichiers temporaires (trap EXIT/INT/TERM)
- **Sécurité** : token saisi en mode silencieux (`read -s`), jamais affiché ni loggé
- **Service systemd étendu** : enable / disable en plus du start/stop/restart

---

## Prérequis

- Distribution Linux avec accès `sudo`
- Bash shell
- `curl` ou `wget` pour le téléchargement depuis URL
- Agent SentinelOne installable (fichier `.rpm` ou `.deb`, ou URL)
- Token de gestion SentinelOne (pour l'enregistrement)

### Distributions testées

| Famille | Distributions |
|---------|--------------|
| RPM | RHEL 7/8/9, Rocky Linux, AlmaLinux, CentOS, Fedora |
| DEB | Ubuntu 20.04/22.04/24.04, Debian 11/12 |

---

## Installation

```bash
# 1. Cloner le dépôt
git clone https://github.com/Rooot3301/Sentinelize.git
cd Sentinelize

# 2. Rendre les scripts exécutables
chmod +x deploy-s1.sh sentinelonectl

# 3. (Optionnel) Créer un fichier de configuration
cp .env.example .env
nano .env

# 4. (Optionnel) Installer sentinelonectl dans /usr/local/bin
sudo ./deploy-s1.sh --install-tools
```

---

## Configuration

Le script utilise un fichier `.env` optionnel, chargé depuis :
1. `$(dirname deploy-s1.sh)/.env`
2. `/etc/sentinelone/.env`
3. `~/.sentinelone.env`

```bash
cp .env.example .env
chmod 600 .env
```

### Variables configurables

```bash
# Chemin vers l'exécutable sentinelctl
S1CTL="/opt/sentinelone/bin/sentinelctl"

# Nom du service systemd
SERVICE_NAME="sentinelone"

# Nom du paquet de l'agent (RPM ou DEB)
AGENT_PACKAGE="sentinelone-agent"

# Fichier de log du script
LOG_FILE="/var/log/s1-manager.log"

# Niveau de log (ERROR | WARN | INFO | DEBUG)
LOG_LEVEL="INFO"
```

---

## Utilisation

### Mode Interactif

```bash
sudo ./deploy-s1.sh
```

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

### Mode CLI (deploy-s1.sh)

```bash
# Afficher l'aide
./deploy-s1.sh --help

# Installer l'agent (RPM ou DEB selon l'OS détecté)
sudo ./deploy-s1.sh --install /path/to/agent.rpm
sudo ./deploy-s1.sh --install https://example.com/agent.rpm

# Configurer le token de management (saisie silencieuse)
sudo ./deploy-s1.sh --set-token

# Vérifier le statut
./deploy-s1.sh --status

# Health check complet
./deploy-s1.sh --health-check

# Afficher la version de l'agent
./deploy-s1.sh --version

# Désinstaller l'agent
sudo ./deploy-s1.sh --uninstall

# Installer sentinelonectl dans /usr/local/bin
sudo ./deploy-s1.sh --install-tools
```

### sentinelonectl

Après `--install-tools`, `sentinelonectl` est disponible globalement :

```bash
# Aide complète
sentinelonectl help

# Menu interactif
sentinelonectl menu
```

#### Référence des commandes

| Groupe | Commande | Description |
|--------|----------|-------------|
| **Installation** | `sentinelonectl install <fichier\|url>` | Installer l'agent |
| | `sentinelonectl uninstall` | Désinstaller l'agent |
| | `sentinelonectl upgrade` | Mettre à jour l'agent |
| | `sentinelonectl token set` | Configurer le token (silencieux) |
| | `sentinelonectl token get` | Afficher le token actuel |
| **Agent** | `sentinelonectl agent start` | Démarrer l'agent |
| | `sentinelonectl agent stop` | Arrêter l'agent |
| | `sentinelonectl agent status` | Statut de l'agent |
| | `sentinelonectl agent version` | Version de l'agent |
| | `sentinelonectl agent detect` | Détecter l'agent |
| | `sentinelonectl agent upgrade` | Mettre à jour l'agent |
| **Scans** | `sentinelonectl scan start` | Démarrer un scan |
| | `sentinelonectl scan abort` | Arrêter le scan |
| | `sentinelonectl scan status` | Statut du scan |
| **Sécurité** | `sentinelonectl policy status` | Statut des policies |
| | `sentinelonectl quarantine list [all\|<groupe>]` | Fichiers en quarantaine |
| | `sentinelonectl firewall` | Opérations firewall |
| **Avancé** | `sentinelonectl engines` | Gestion des engines |
| | `sentinelonectl asset` | Gestion des assets |
| | `sentinelonectl management` | Informations management |
| | `sentinelonectl raw <args>` | Commande sentinelctl brute |
| **Logs** | `sentinelonectl log` | Logs de l'agent |
| | `sentinelonectl logs agent` | Logs agent (sentinelctl) |
| | `sentinelonectl logs service` | Logs systemd |
| | `sentinelonectl logs manager` | Logs du script |
| **Service** | `sentinelonectl service start` | Démarrer le service |
| | `sentinelonectl service stop` | Arrêter le service |
| | `sentinelonectl service restart` | Redémarrer le service |
| | `sentinelonectl service status` | Statut du service |
| | `sentinelonectl service enable` | Activer au démarrage |
| | `sentinelonectl service disable` | Désactiver au démarrage |
| | `sentinelonectl service reload` | Recharger la config |
| **Diagnostic** | `sentinelonectl status` | Statut global |
| | `sentinelonectl health` | Health check complet |
| | `sentinelonectl version` | Version de l'agent |

---

## Fonctionnalités

### Support multi-OS

Le script détecte automatiquement l'OS via `/etc/os-release` et sélectionne le gestionnaire approprié :

| Famille | Gestionnaire | Commande d'installation |
|---------|-------------|------------------------|
| RPM | dnf / yum / rpm | `rpm -ivh --noverify` |
| DEB | apt / apt-get / dpkg | `dpkg -i` |

### Health Check

```bash
./deploy-s1.sh --health-check
# ou
sentinelonectl health
```

Sortie exemple :
```
➤ Système : Ubuntu 22.04 (deb)
   [OK] sentinelctl : DISPONIBLE (/opt/sentinelone/bin/sentinelctl)

➤ État du service systemd
   [OK] Activation auto-démarrage : ACTIVÉ
   [OK] État actuel : EN COURS D'EXÉCUTION

➤ Version de l'agent
   Agent version: 23.x.x.xxx

[OK] Health Check global : TOUS LES TESTS RÉUSSIS
```

---

## Exemples

### Installation complète en mode non-interactif

```bash
# Télécharger et installer l'agent
sudo ./deploy-s1.sh --install https://example.com/sentinelone-agent.rpm

# Configurer le token (prompt silencieux)
sudo ./deploy-s1.sh --set-token

# Vérifier
./deploy-s1.sh --health-check
```

### Automatisation complète

```bash
#!/bin/bash
AGENT_URL="https://example.com/sentinelone-agent.rpm"

sudo ./deploy-s1.sh --install "$AGENT_URL"
sudo ./deploy-s1.sh --set-token
sudo ./deploy-s1.sh --health-check
```

### Lancer un scan via sentinelonectl

```bash
sentinelonectl scan start
sentinelonectl scan status
```

### Gestion du service

```bash
sentinelonectl service enable    # activer au démarrage
sentinelonectl service restart   # redémarrer
sentinelonectl service status    # vérifier
```

---

## Logs

Le script génère des logs dans `/var/log/s1-manager.log` (configurable via `.env`).

- Rotation automatique (> 1 Mo)
- Niveaux : `ERROR`, `WARN`, `INFO`, `DEBUG`
- Format : `[YYYY-MM-DD HH:MM:SS] [LEVEL] message`

```bash
# Via sentinelonectl
sentinelonectl logs manager   # logs du script
sentinelonectl logs agent     # logs de l'agent
sentinelonectl logs service   # logs systemd
```

---

## Sécurité

- **Token** : saisi en mode silencieux (`read -s`), jamais affiché ni loggé
- **Fichiers temporaires** : supprimés automatiquement même en cas d'interruption (trap)
- **GPG** : installation RPM avec `--noverify` pour les paquets SentinelOne non signés publiquement
- **Permissions `.env`** :
  ```bash
  chmod 600 .env
  ```

---

## Licence

Ce script est proposé à titre éducatif et professionnel. Libre de modification et distribution avec attribution de l'auteur original.

---

**Auteur** : Root3301
**Version** : 3.0
**Date** : Mars 2026
