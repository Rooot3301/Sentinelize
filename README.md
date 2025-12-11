# 🛡️ SentinelOne Agent Manager v2.0

---

## 🚀 Présentation

Bienvenue dans **SentinelOne Agent Manager v2.0** !
Un script Bash avancé, interactif et complet pour gérer l'agent SentinelOne sur Linux avec une interface organisée en sous-menus.

Ce script permet de :

### 📦 Installation & Configuration
- ✅ Installer l'agent depuis un fichier RPM local ou une URL
- ✅ Configurer le token de management
- ✅ Mettre à jour l'agent
- ✅ Désinstaller l'agent

### 🎯 Contrôle de l'agent
- ✅ Démarrer/Arrêter l'agent
- ✅ Vérifier le statut et la version
- ✅ Détection de l'agent

### 🛡️ Opérations de sécurité
- ✅ Lancer, arrêter et surveiller des scans
- ✅ Consulter le statut des policies
- ✅ Gérer les fichiers en quarantaine
- ✅ Opérations firewall

### 📊 Monitoring & Diagnostic
- ✅ Health check complet
- ✅ Consultation des logs (agent, script, systemd)
- ✅ Statut détaillé du service

### ⚙️ Configuration avancée
- ✅ Gestion des assets
- ✅ Opérations sur les engines

### 🔧 Gestion du service systemd
- ✅ Contrôle complet du service (start, stop, restart, status)

> **Auteur** : Root3301
> **Version** : 2.0
> **Date** : Décembre 2025

---

## 🛠️ Prérequis

- ✅ Distribution Linux avec accès `sudo`
- ✅ Bash shell
- ✅ `curl` pour le téléchargement depuis URL
- ✅ Chemin de l'outil `sentinelctl` par défaut : `/opt/sentinelone/bin/sentinelctl`
- ✅ (Optionnel) Fichier RPM de l'agent SentinelOne ou URL de téléchargement
- ✅ (Optionnel) Token de gestion SentinelOne

---

## 📥 Installation & Lancement

```bash
# 1. Télécharger ou copier le script
wget https://example.com/deploy-s1.sh
# ou
curl -O https://example.com/deploy-s1.sh

# 2. Rendre le script exécutable
chmod +x deploy-s1.sh

# 3. Lancer le script en mode interactif
./deploy-s1.sh

# Ou en mode CLI (non-interactif)
./deploy-s1.sh --help
```

---

## 📋 Mode Interactif

Au lancement, le script affiche un menu principal organisé par catégories :

```
╔═════════════════════════════════════════════════════════╗
║  MENU PRINCIPAL                                         ║
╠═════════════════════════════════════════════════════════╣
║  [1] 📦 Installation & Configuration                    ║
║  [2] 🎯 Contrôle de l'agent                             ║
║  [3] 🛡️  Opérations de sécurité                         ║
║  [4] 📊 Monitoring & Diagnostic                         ║
║  [5] ⚙️  Configuration avancée                          ║
║  [6] 🔧 Gestion du service systemd                      ║
╠═════════════════════════════════════════════════════════╣
║  [0] 🚪 Quitter                                         ║
╚═════════════════════════════════════════════════════════╝
```

Chaque option mène à un sous-menu détaillé avec les opérations spécifiques.

---

## 🖥️ Mode CLI (Non-interactif)

Le script peut également être utilisé en ligne de commande pour l'automatisation :

```bash
# Installer l'agent depuis un fichier local
sudo ./deploy-s1.sh --install-rpm /path/to/agent.rpm

# Installer l'agent depuis une URL
sudo ./deploy-s1.sh --install-rpm https://example.com/agent.rpm

# Configurer le token
sudo ./deploy-s1.sh --set-token "YOUR_TOKEN_HERE"

# Vérifier le statut
./deploy-s1.sh --status

# Health check complet
./deploy-s1.sh --health-check

# Afficher la version
./deploy-s1.sh --version

# Afficher l'aide
./deploy-s1.sh --help
```

---

## 🧰 Détail des fonctionnalités

### 📦 Installation & Configuration
- Installer depuis un fichier RPM local ou une URL
- Configurer le token de management
- Mettre à jour l'agent (via sentinelctl control upgrade)
- Désinstaller l'agent

### 🎯 Contrôle de l'agent
- Démarrer/Arrêter l'agent via sentinelctl
- Vérifier le statut détaillé
- Afficher la version installée
- Détection de l'agent

### 🛡️ Opérations de sécurité
- **Scans** : Démarrer, arrêter, vérifier le statut
- **Policies** : Consulter le statut des policies
- **Quarantine** : Lister les fichiers en quarantaine (tous ou par groupe)
- **Firewall** : Opérations de contrôle du firewall

### 📊 Monitoring & Diagnostic
- Health check complet (système, service, agent)
- Consultation des logs de l'agent
- Logs du script et systemd
- Vue d'ensemble du statut

### ⚙️ Configuration avancée
- Gestion des assets
- Opérations sur les engines

### 🔧 Gestion du service systemd
- Statut du service
- Démarrer/Arrêter/Redémarrer le service

---

## 🎨 Personnalisation

### Variables d'environnement
Créer un fichier `.env` à côté du script pour personnaliser les paramètres :

```bash
# Chemin vers sentinelctl
S1CTL="/opt/sentinelone/bin/sentinelctl"

# Nom du service systemd
SERVICE_NAME="sentinelone"

# Nom du paquet RPM
AGENT_PACKAGE="sentinelone-agent"

# Fichier de log
LOG_FILE="/var/log/s1-manager.log"

# Niveau de log (ERROR | WARN | INFO | DEBUG)
LOG_LEVEL="INFO"
```

### Logs
Le script génère automatiquement des logs dans `/var/log/s1-manager.log` avec :
- Rotation automatique des logs (> 1 Mo)
- Niveaux de log configurables
- Horodatage des événements

---

## 🧪 Exemple d'utilisation

### Installation depuis une URL
```bash
$ sudo ./deploy-s1.sh

# Menu principal → [1] Installation & Configuration
# Sous-menu → [1] Installer l'agent SentinelOne (RPM)
# Choix → [2] URL de téléchargement
# URL → https://example.com/sentinelone-agent.rpm

✓ Fichier téléchargé
✓ Agent installé avec succès
```

### Lancer un scan de sécurité
```bash
$ sudo ./deploy-s1.sh

# Menu principal → [3] Opérations de sécurité
# Sous-menu → [1] Démarrer un scan

✓ Scan démarré avec succès
```

### Health check complet
```bash
$ sudo ./deploy-s1.sh --health-check

➤ Vérifications système
   ✓ sentinelctl : DISPONIBLE
➤ État du service systemd
   ✓ Activation auto-démarrage : ACTIVÉ
   ✓ État actuel : EN COURS D'EXÉCUTION
➤ Statut de l'agent
   [détails du statut...]
✓ Health Check global : TOUS LES TESTS RÉUSSIS
```

---

## ⚠️ Gestion des erreurs

- 🔒 Chaque action critique est vérifiée automatiquement
- 📝 Tous les événements sont journalisés
- ❌ Messages d'erreur clairs et colorés
- 🔄 Nettoyage automatique des fichiers temporaires
- ✅ Validation des paramètres avant exécution

---

## 🔐 Sécurité

- Privilèges sudo requis pour les opérations critiques
- Validation des fichiers avant installation
- Nettoyage des fichiers temporaires après téléchargement
- Logs sécurisés des opérations

---

## 📄 Licence

Ce script est proposé à titre éducatif et professionnel.
Libre de modification et distribution avec attribution de l'auteur original.

---

## 🤝 Contribution

Les contributions sont les bienvenues ! N'hésite pas à :
- Signaler des bugs
- Proposer des améliorations
- Ajouter de nouvelles fonctionnalités

---

**Développé avec ❤️ par Root3301**



