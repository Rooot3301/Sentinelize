🛡️ SentinelOne Deployment Manager - CLI Edition
🚀 Présentation
Bienvenue dans SentinelOne Deployment Manager - CLI Edition !
Un script Bash simple, interactif et efficace pour gérer l'installation et la configuration de l'agent SentinelOne sur Linux.

Ce script permet de :

Installer un agent SentinelOne à partir d'un fichier RPM

Ajouter un token de gestion pour l'enregistrement auprès de la console SentinelOne

Vérifier le statut de l'agent en temps réel

Consulter la version installée de l'agent

Auteur : Romain Varene
Date : 19 mai 2025

🛠️ Prérequis
Distribution Linux avec accès sudo

Fichier RPM de l'agent SentinelOne prêt à être installé

Token de gestion SentinelOne

Bash shell

Chemin de l’outil sentinelctl par défaut : /opt/sentinelone/bin/sentinelctl

📥 Installation & Lancement
Téléchargez ou copiez le script dans un fichier, par exemple :

sentinelone_manager.sh

Rendez-le exécutable :

bash
Copier
Modifier
chmod +x sentinelone_manager.sh
Exécutez le script :

bash
Copier
Modifier
./sentinelone_manager.sh
📋 Utilisation
Au lancement, le script affiche un menu interactif :

rust
Copier
Modifier
Que souhaitez-vous faire ?
1 - Installer un agent SentinelOne
2 - Ajouter un token de gestion
3 - Vérifier le statut de l'agent
4 - Vérifier la version de l'agent
5 - Quitter
Choix [1-5] :
Détail des options
Option	Fonctionnalité
1	Installer un agent à partir d’un fichier RPM
2	Ajouter un token d’enregistrement
3	Afficher le statut actuel de l’agent SentinelOne
4	Afficher la version installée de l’agent
5	Quitter le gestionnaire

🎨 Personnalisation
Si l’emplacement de sentinelctl est différent, modifiez la variable S1CTL au début du script :

bash
Copier
Modifier
S1CTL="/chemin/vers/sentinelctl"
Vous pouvez facilement étendre les fonctionnalités en ajoutant de nouvelles fonctions et options au menu.

🔎 Exemple d’utilisation
bash
Copier
Modifier
$ ./sentinelone_manager.sh

╔════════════════════════════════════════════════════════╗
║             SENTINELONE MANAGER - TERMINAL             ║
║        Interface interactive - Romain Varene           ║
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
⚠️ Gestion des erreurs
Le script vérifie la réussite de chaque commande importante.

En cas d’erreur (fichier manquant, token vide, échec d’installation), un message d’erreur s’affiche en rouge et le script s’arrête proprement.

📄 Licence
Ce script est libre d’utilisation, modification et distribution.
N’hésitez pas à l’adapter à vos besoins !

