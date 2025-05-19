# 🛡️ SentinelOne Deployment Manager - CLI Edition

---

## 🚀 Présentation

Bienvenue dans **SentinelOne Deployment Manager - CLI Edition** !  
Un script Bash simple, interactif et efficace pour gérer l'installation et la configuration de l'agent SentinelOne sur Linux.

Ce script permet de :

- ✅ Installer un agent SentinelOne à partir d'un fichier RPM  
- ✅ Ajouter un token de gestion pour l'enregistrement auprès de la console SentinelOne  
- ✅ Vérifier le statut de l'agent en temps réel  
- ✅ Consulter la version installée de l'agent  

> **Auteur** : Root3301  
> **Date** : 19 mai 2025  

---

## 🛠️ Prérequis

- ✅ Distribution Linux avec accès `sudo`  
- ✅ Fichier RPM de l'agent SentinelOne prêt à être installé  
- ✅ Token de gestion SentinelOne  
- ✅ Bash shell  
- ✅ Chemin de l’outil `sentinelctl` par défaut : `/opt/sentinelone/bin/sentinelctl`  

---

## 📥 Installation & Lancement

```bash
# 1. Cloner le repo ou copier le script
nano sentinelone_manager.sh

# 2. Rendre le script exécutable
chmod +x sentinelone_manager.sh

# 3. Lancer le script
./sentinelone_manager.sh
```

## 📋 Utilisation
Au lancement, le script affiche un menu interactif :

```
╔════════════════════════════════════════════════════════╗
║             SENTINELONE MANAGER - TERMINAL             ║
║        Interface interactive - Root3301                ║
╚════════════════════════════════════════════════════════╝

Que souhaitez-vous faire ?
1 - Installer un agent SentinelOne
2 - Ajouter un token de gestion
3 - Vérifier le statut de l'agent
4 - Vérifier la version de l'agent
5 - Quitter
```
# 🧰 Détail des options

| Option | Fonctionnalité                                  |
| ------ | ----------------------------------------------- |
| `1`    | Installer un agent à partir d’un fichier `.rpm` |
| `2`    | Ajouter un token d’enregistrement SentinelOne   |
| `3`    | Afficher le statut actuel de l’agent            |
| `4`    | Afficher la version de l’agent installé         |
| `5`    | Quitter le gestionnaire                         |

# 🎨 Personnalisation
Si l’emplacement de sentinelctl est différent du chemin par défaut, modifie la ligne suivante dans le script :

```
S1CTL="/chemin/personnalisé/vers/sentinelctl"
```
Tu peux aussi ajouter d'autres fonctions (comme la suppression de l'agent, la réinitialisation, etc.) pour élargir les capacités du script.

# 🧪 Exemple d'utilisation
```
$ ./sentinelone_manager.sh

╔════════════════════════════════════════════════════════╗
║             SENTINELONE MANAGER - TERMINAL             ║
║        Interface interactive - Root33301               ║
╚════════════════════════════════════════════════════════╝

Que souhaitez-vous faire ?
1 - Installer un agent SentinelOne
2 - Ajouter un token de gestion
3 - Vérifier le statut de l'agent
4 - Vérifier la version de l'agent
5 - Quitter

Choix [1-5] : 1

Installation de l'agent SentinelOne
Chemin vers le fichier RPM (.rpm) : /home/romain/agent.rpm
[INFO] Agent installé avec succès.

Appuyez sur Entrée pour revenir au menu principal...
```
# ⚠️ Gestion des erreurs
🔒 Chaque action critique est suivie d’une vérification automatique (check_success).
❌ En cas d’erreur (token vide, fichier manquant, installation échouée), un message rouge s’affiche et le script interrompt proprement l’action en cours.

# 📄 Licence
Ce script est proposé à titre éducatif et peut être librement modifié et distribué.
Si tu l'améliores, n’hésite pas à contribuer ou à me ping si tu veux bosser dessus à plusieurs 😉



