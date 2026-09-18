# SRC SCHOOL — Feuille de route de réalisation

## Objectif

Livrer d'abord les parcours essentiels de la première version commerciale décrite dans le PowerPoint : gestion multi-écoles, administration scolaire, pédagogie, finances et communication parent. La stack décidée est Next.js pour admin/super admin web, Flutter pour desktop/mobile, FastAPI pour le backend commun et PostgreSQL pour la persistance.

Le dossier `design/` est la référence visuelle permanente : le consulter avant chaque écran ou évolution graphique, puis vérifier la cohérence des couleurs, polices, densité, navigation et composants. Adapter les références aux rôles scolaires et aux contraintes d'accessibilité ; ne pas reproduire des textes ou données sans rapport avec le produit.

## Équipe d'agents et coordination

Avec quatre agents actifs maximum, le pilote coordonne les contrats et l'intégration pendant que trois spécialistes travaillent sur des périmètres de fichiers distincts. Les rôles peuvent être réaffectés entre les phases.

| Rôle | Responsabilité | Livrable et interface avec les autres |
| --- | --- | --- |
| Pilote / intégration | Priorités MVP, décisions, intégration et recette transversale | Contrats partagés, configuration du dépôt, compte rendu des vérifications et limites |
| Backend / données | FastAPI, PostgreSQL, authentification, isolation écoles, métier | Migrations, API documentée, données fictives et vérifications des permissions |
| Web / design | Next.js admin et super admin, déclinaison de `design/` | Parcours reliés à l'API, états d'interface complets et composants cohérents |
| Flutter / clients | Desktop admin/comptable et mobile enseignant | Authentification, lecture et mutations via la même API, builds des plateformes disponibles |

Les agents synchronisent les routes, champs, rôles et formats d'erreur avant de développer les consommateurs. Aucun agent ne modifie les fichiers d'un autre sans coordination. À la fin d'une tranche métier, la recette vérifie un aller-retour réel entre client, API et PostgreSQL. Les tâches de documentation et de vérification peuvent être confiées à un spécialiste disponible une fois son lot intégré.

## Phases et critères de passage

### 1. Fondations et première tranche verticale

- Lire le PowerPoint, examiner les images `design/` et vérifier les compétences locales `apple-design` et `superdesign`.
- Documenter rôles, navigation, conventions graphiques et contrat API.
- Mettre en place le dépôt, la configuration de développement, PostgreSQL et les migrations.
- Implémenter authentification et autorisations, création d'une école et accès de son administrateur.
- Vérifier que les données persistent après redémarrage et que l'école A ne peut accéder à B.

Passage : connexion et gestion d'une école fonctionnent depuis le web avec l'API et PostgreSQL. La présence d'une maquette seule ne valide pas cette phase.

### 2. Administration scolaire et connexion Flutter

- Années scolaires, classes, matières, enseignants, affectations, élèves, tuteurs et inscriptions.
- Écrans administrateur Next.js et navigation par rôle.
- Client Flutter commun, configuration API, session et liste des classes affectées.
- Flutter desktop : accès de l'administrateur aux parcours administratifs retenus.

Passage : un élève inscrit sur le web apparaît dans la bonne classe mobile ; les autorisations sont testées par appels directs à l'API.

### 3. Pédagogie et finances

- Présences, notes, devoirs simples avec échéance et suivi des remises, emploi du temps et bulletins PDF.
- Frais, paiements, reçus, soldes et rapports d'impayés.
- Interfaces Flutter enseignant et comptable reliées aux opérations réelles.
- Tableau de bord alimenté par les enregistrements métier ; audit des actions sensibles.

Passage : présence et note mobile sont visibles par l'administrateur ; paiement desktop actualise le solde et génère un reçu. Les documents PDF sont téléchargeables et protégés.

### 4. SaaS et communication parent

- Gestion des plans, périodes d'abonnement, activation/suspension et statistiques.
- Boîte d'envoi persistante, suivi des erreurs et protection contre les doublons de notification.
- Intégration WhatsApp avec compte configuré, annonces, absence/note, solde et bulletin sécurisé.
- Notifications nécessaires à l'enseignant ; mécanisme et délai de synchronisation documentés.

Passage : les messages configurés atteignent les destinataires de test ; les échecs sont visibles et ne sont jamais présentés comme une livraison réussie. Une simulation permet d'avancer sans identifiants mais laisse ce critère ouvert.

### 5. Recette et préparation du pilote

- Exécuter les scénarios de `mvp-acceptance.md`, en particulier isolation multi-écoles, droits, documents et cohérence financière.
- Compiler et essayer les applications sur les plateformes effectivement disponibles ; consigner celles non testées.
- Vérifier installation vierge, migrations, sauvegarde/restauration et configuration de production.
- Revoir les écrans par rapport à `design/`, les erreurs de formulaire, la lisibilité et l'usage au clavier/tactile.
- Préparer guide de lancement, comptes fictifs locaux et inventaire des paramètres externes.

Passage : aucune fonction essentielle annoncée comme terminée ne dépend d'un bouton inactif, de données codées en dur ou d'un service simulé non signalé.

### 6. Pilote puis amélioration

Déployer dans l'environnement autorisé et accompagner deux à trois établissements pilotes, conformément au PowerPoint. Mesurer les erreurs, la compréhension des parcours et les besoins réels avant de fixer les tarifs commerciaux. Prioriser ensuite les améliorations d’ergonomie et les compléments identifiés dans les retours terrain.

## Décisions et dépendances à suivre

Les choix déjà décidés par le porteur du projet ne demandent pas de nouvelle validation : stack et présence des administrateurs sur le web. Les règles de calcul scolaire, la portée exacte d'éventuelles fonctions hors connexion, les plateformes desktop cibles et la configuration WhatsApp doivent être documentées à mesure que leur mise en œuvre devient nécessaire. Ne pas présenter une hypothèse d'implémentation comme une exigence du PowerPoint.

Il n'existe pas d'estimation de calendrier fiable avant l'inspection de l'environnement, la stabilisation du contrat métier et la première tranche verticale. Rapporter les fonctionnalités opérationnelles, les vérifications exécutées et les obstacles concrets à chaque livraison, plutôt qu'un pourcentage de progression arbitraire.
