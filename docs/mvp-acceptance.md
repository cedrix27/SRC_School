# SRC SCHOOL — Critères de recette du MVP

## Référence et décisions

Source fonctionnelle : `SRC_SCHOOL_Presentation (1).pptx`, en particulier les diapositives 7 à 12. Les choix exprimés par le porteur du projet priment sur les alternatives du diaporama : Next.js pour les interfaces web administrateur et super administrateur, Flutter pour desktop et mobile, FastAPI pour une API commune et PostgreSQL pour les données.

L'administrateur doit donc disposer d'une interface web, même si le diaporama le place sur desktop. Le comptable utilise Flutter desktop et l'enseignant Flutter mobile. L'administrateur desktop reste prévu conformément au diaporama. Le parent utilise WhatsApp et des liens sécurisés vers ses documents ; une application parent n'est pas nécessaire au MVP.

Ce document décrit les conditions de livraison. Une ligne ci-dessous n'est pas une preuve d'implémentation : chaque scénario devra être exécuté et son résultat consigné avant de déclarer le MVP complet.

## Jeu de données de recette

- Deux écoles distinctes A et B, avec leurs administrateurs, comptables et enseignants.
- Un super administrateur de plateforme.
- Deux années scolaires, deux classes par école, plusieurs matières et des affectations enseignant/classe/matière.
- Des élèves inscrits, des contacts de tuteurs et une inscription dans l'année précédente pour vérifier l'historique.
- Des frais de scolarité, cantine et transport, un règlement partiel et un solde totalement réglé.
- Des notes et des présences, y compris un élève absent et un élève sans note.

Utiliser uniquement des données fictives pendant le développement et les tests.

## Scénarios fonctionnels de bout en bout

| ID | Parcours et action | Résultat attendu |
| --- | --- | --- |
| AUTH-01 | Se connecter sur Next.js et Flutter avec chaque rôle, puis se déconnecter. | Le serveur vérifie les identifiants ; seules les fonctions autorisées sont accessibles ; la déconnexion invalide la session selon le mécanisme retenu. |
| AUTH-02 | Saisir un mot de passe incorrect, appeler une API sans session, puis avec une session expirée. | Refus contrôlé, message compréhensible et absence de données privées. |
| SA-01 | Créer l'école A et son administrateur sur le web, puis se connecter avec cet administrateur. | L'école et son espace isolé existent réellement dans PostgreSQL et restent disponibles après redémarrage. |
| SA-02 | Suspendre une école, essayer ses comptes, puis la réactiver. | Les accès métier sont bloqués durant la suspension, puis rétablis ; les données sont conservées. |
| SA-03 | Affecter un plan et une période d'abonnement à une école. | Le statut et les statistiques du tableau de bord reflètent les enregistrements persistés ; aucun encaissement automatique n'est prétendu s'il n'est pas intégré. |
| ADM-01 | Créer une classe, une matière, un enseignant et une affectation, sur le web. | L'enseignant retrouve uniquement ses classes et matières dans Flutter. |
| ADM-02 | Créer un élève, un tuteur et son inscription ; modifier les coordonnées et rouvrir la fiche. | Les modifications persistent ; l'inscription rattache explicitement élève, classe et année scolaire. |
| ADM-03 | Tenter une inscription en double, puis consulter l'année précédente. | Le doublon est contrôlé et les anciennes inscriptions restent consultables. |
| ADM-04 | Créer un créneau d'emploi du temps et le consulter sur mobile. | Jour, horaire, classe, matière et enseignant correspondent ; les conflits applicables sont signalés. |
| PED-01 | L'enseignant marque une présence et une absence depuis Flutter, puis l'administrateur ouvre le suivi. | Les données sauvegardées sont visibles avec leur date ; un nouvel enregistrement identique ne crée pas de doublon. Le délai de synchronisation est documenté. |
| PED-02 | Saisir puis corriger une note dans une matière affectée. | Les bornes sont validées ; la correction est visible côté administration et auditée. Une matière non affectée reste interdite. |
| PED-03 | Générer un bulletin pour une période contenant notes et absences. | Un vrai PDF téléchargeable présente le bon élève, l'école, l'année, la période et des calculs reproductibles. Une note manquante n'est pas transformée silencieusement en zéro. |
| FIN-01 | Créer des frais et les affecter à un élève, puis enregistrer un paiement partiel depuis le desktop. | Le montant dû et le solde restant sont exacts ; le paiement est persistant et lié à son auteur. |
| FIN-02 | Répéter une soumission de paiement, saisir un montant négatif, puis solder les frais. | Aucun double encaissement accidentel ; montant invalide refusé ; le solde final est exact. La politique de trop-perçu est explicite. |
| FIN-03 | Télécharger un reçu et consulter les impayés et le rapport financier. | Le reçu est un document réel identifié, les impayés excluent les soldes réglés et les totaux correspondent aux transactions. |
| COM-01 | Enregistrer une absence ou une nouvelle note pour un élève avec un tuteur joignable. | Une notification est produite et son état est suivi. En mode WhatsApp réel, le bon tuteur reçoit le message via le fournisseur configuré. |
| COM-02 | Envoyer une annonce et un rappel de solde depuis l'école. | Les destinataires sont limités à l'école ; le solde vient du registre financier ; erreurs et tentatives sont visibles. |
| COM-03 | Ouvrir le lien WhatsApp d'un bulletin, puis essayer un lien expiré ou altéré. | Le document attendu est accessible pendant sa validité ; les liens invalides ne donnent accès à aucun bulletin. |
| UI-01 | Exécuter les parcours sur web, Flutter desktop et Flutter mobile. | Navigation, formulaires, validation, états vides, chargement et erreurs fonctionnent ; les choix de style s'appuient sur `design/`. |
| DATA-01 | Créer un enregistrement, redémarrer API et clients, puis consulter les trois interfaces. | Une source de vérité PostgreSQL cohérente ; aucune donnée métier dépendante d'un simple état mémoire ou d'un jeu de démonstration. |

PED-04 — L’enseignant crée un devoir dans une classe affectée, indique une échéance et suit les remises. Le devoir persiste après reconnexion ; les élèves et enseignants hors affectation sont refusés. Les devoirs simples de la diapositive 8 sont conservés dans le MVP pour couvrir les fonctionnalités annoncées.

## Sécurité et exploitation

| ID | Vérification | Résultat attendu |
| --- | --- | --- |
| SEC-01 | Un compte de l'école A demande une liste, un objet, un PDF ou une mutation de B, en remplaçant les identifiants. | Refus côté API pour chaque type de ressource ; aucun filtrage reposant uniquement sur l'interface. |
| SEC-02 | Un enseignant appelle une route comptable ; un comptable modifie des notes ; un administrateur appelle la gestion globale. | Refus côté serveur, y compris pour les appels directs. |
| SEC-03 | Inspecter les comptes et les réponses API. | Aucun mot de passe en clair dans la base, les journaux ou les réponses ; aucun secret exposé au client. |
| SEC-04 | Répéter des connexions erronées et envoyer des entrées invalides. | Limitation des tentatives et validation serveur vérifiables. |
| SEC-05 | Modifier note, paiement, école ou droits, puis consulter l'audit. | Auteur, action, ressource, école et date sont traçables sans exposer les secrets. |
| OPS-01 | Installer depuis un environnement vierge avec les instructions du dépôt. | Migrations, configuration, lancement et données de démonstration sont reproductibles. |
| OPS-02 | Sauvegarder PostgreSQL puis restaurer dans une base distincte. | Les enregistrements et relations vérifiés avant sauvegarde sont retrouvés après restauration. |
| OPS-03 | Tester l'environnement destiné au pilote. | HTTPS, secrets, sauvegardes quotidiennes et remontée des erreurs sont configurés ; aucun compte de démonstration partagé en production. |

## Dépendances externes et limites à afficher

- WhatsApp réel : compte fournisseur, numéro autorisé, identifiants, modèles de messages nécessaires et configuration des retours de livraison. Sans ces éléments, une boîte d'envoi de développement permet la recette interne mais ne valide pas la réception WhatsApp.
- Abonnements SaaS : la gestion des plans et périodes est incluse. Un prestataire de paiement et les prélèvements automatiques ne sont pas imposés par le diaporama. Les tarifs mentionnés sont indicatifs, pas une décision commerciale.
- Flutter : SDK et outils de compilation des plateformes cibles requis. Une compilation macOS ne prouve pas une compilation Windows, Android ou iOS.
- Pilote : hébergement, domaine, configuration de production et établissements pilotes restent nécessaires au lancement réel.
- Bulletins : coefficients, barème, périodes et règles d'arrondi doivent être explicites ; une règle provisoire doit être documentée et configurable.

## Condition de livraison

Un MVP complet exige une preuve de réussite des parcours web, desktop, mobile et WhatsApp configuré, avec PostgreSQL et contrôle des droits. Un écran, un scaffold Flutter, une simulation d'envoi ou des tests unitaires seuls ne suffisent pas. Le compte rendu de livraison doit distinguer les scénarios réussis, les échecs et les dépendances externes non configurées, avec les commandes de vérification effectivement exécutées.
