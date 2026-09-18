# SRC SCHOOL — Architecture du MVP

## Source et décisions

Source fonctionnelle : `SRC_SCHOOL_Presentation (1).pptx`, 15 diapositives, septembre 2026. Choix confirmés par le porteur : Next.js pour les administrateurs web et le super administrateur, Flutter pour desktop et mobile, FastAPI pour l'API commune, PostgreSQL pour les données.

Ce document décrit la cible et les critères de livraison ; il ne certifie pas que les fonctionnalités sont déjà implémentées. Le dossier `design/` reste la référence visuelle de toutes les interfaces : couleurs, typographie, hiérarchie, composants et états doivent être vérifiés contre ses ressources avant chaque évolution.

## Interfaces et responsabilités

| Interface | Public | Fonctions MVP |
| --- | --- | --- |
| Next.js web | Super administrateur SRC DIGITAL | Écoles, activation/suspension, plans, abonnements, statistiques SaaS |
| Next.js web | Administrateur école | Gestion scolaire et supervision financière de son école |
| Flutter desktop | Administrateur école | Élèves, inscriptions, classes, enseignants, matières, présences, notes, bulletins, communications |
| Flutter desktop | Comptable | Frais, échéances, encaissements, reçus, impayés, rapports, rappels |
| Flutter mobile | Enseignant | Classes attribuées, emploi du temps, présences, notes, devoirs et notifications |
| WhatsApp | Parent/tuteur | Absences, notes publiées, solde, annonces et accès sécurisé au bulletin |

Les devoirs figurent dans la diapositive 8 et restent inclus. Le parent n'a pas de compte applicatif dans cette version. L'enregistrement d'un paiement reçu est inclus ; l'encaissement automatique par Mobile Money ou carte nécessite un prestataire et ne doit pas être présenté comme déjà connecté.

## Organisation technique

Un monolithe FastAPI modulaire expose `/api/v1`. Next.js et Flutter consomment le même contrat OpenAPI. La logique métier, les autorisations, les calculs financiers et les moyennes résident dans l'API. Aucun client ne se connecte directement à PostgreSQL.

Modules : identité, plateforme SaaS, scolarité, pédagogie, finances, communications, documents, audit. PostgreSQL conserve les données métier et une file transactionnelle `outbox`. Un worker traite les PDF et messages après commit, avec reprises et identifiants d'idempotence. Redis peut servir au rate limiting et à la diffusion d'événements en production ; une instance Redis ne devient pas la source des données métier.

L'API persiste immédiatement les présences et notes. Un flux d'événements authentifié ou une actualisation périodique permet leur consultation rapide sur les autres interfaces. Le MVP exige une connexion : un état non sauvegardé doit être visible, sans fausse confirmation de synchronisation. Le mode hors connexion avec résolution de conflits est une extension.

## Modèle de données et isolation

Identifiants UUID, horodatages UTC, fuseau configurable par école, dates scolaires locales. Les sommes sont stockées en unités monétaires entières avec code devise ; pour la devise XOF du PPT, une unité est un franc CFA. Les notes et coefficients utilisent des décimaux exacts.

| Domaine | Entités et contraintes principales |
| --- | --- |
| Plateforme | `schools`, `plans`, `subscriptions`, `subscription_payments` ; les tarifs du PPT sont des exemples configurables, pas des prix commerciaux validés |
| Identité | `users`, `memberships(user_id, school_id, role)`, `sessions`, `password_reset_tokens` |
| Scolarité | `academic_years`, `terms`, `classes`, `students`, `guardians`, `student_guardians`, `enrollments` ; une inscription active par élève et année |
| Enseignement | `subjects`, `teaching_assignments`, `timetable_slots`, `assignments`, `assignment_progress` |
| Présences | `attendance_sessions`, `attendance_records` ; unicité `(session_id, enrollment_id)` |
| Évaluation | `assessments`, `grades`, `report_cards` ; unicité `(assessment_id, enrollment_id)` ; publication et version du bulletin explicites |
| Finances | `fee_definitions`, `charges`, `payments`, `payment_allocations`, `payment_reversals`, `receipts` |
| Communication | `announcements`, `notifications`, `message_deliveries`, `guardian_consents`, `document_access_tokens`, `outbox_events` |
| Traçabilité | `audit_events`, `idempotency_records` |

Chaque table appartenant à une école porte `school_id NOT NULL`. Les contraintes uniques sont limitées à l'école lorsque nécessaire. Les relations utilisent des clés étrangères composées `(school_id, id)` pour interdire les références entre établissements. L'API déduit l'école de l'appartenance active vérifiée, jamais d'un champ du corps accepté sans contrôle.

Les requêtes métier filtrent systématiquement `school_id`. En production, PostgreSQL Row Level Security complète ce filtrage avec `SET LOCAL` dans la transaction ; le rôle applicatif n'est ni propriétaire des tables ni `BYPASSRLS`. Les tâches du worker ouvrent également un contexte d'école. Des tests avec deux établissements doivent démontrer l'absence de fuite par liste, détail, modification, PDF et événements.

## Identité et RBAC

Mots de passe hachés avec un algorithme adapté, jetons d'accès courts et sessions renouvelables révocables. Web : session dans un cookie HttpOnly, Secure en HTTPS, SameSite et protection CSRF des mutations. Flutter : secrets dans le stockage sécurisé du système, jamais dans les préférences ordinaires. CORS limite les origines connues. Aucun mot de passe de démonstration ne convient à la production.

| Action | Super admin | Admin école | Comptable | Enseignant |
| --- | --- | --- | --- | --- |
| Écoles/plans/abonnements | Oui | Non | Non | Non |
| Élèves/classes/personnel | Non par défaut | Oui | Lecture minimale pour facturer | Classes attribuées uniquement |
| Présences/notes | Non par défaut | Oui | Non | Enseignements attribués uniquement |
| Publication bulletins | Non | Oui | Non | Lecture de ses classes selon attribution |
| Frais/paiements/reçus | Non par défaut | Oui | Oui | Non |
| Communications | Plateforme uniquement | Oui | Rappels financiers | Notifications pédagogiques autorisées |
| Audit école | Non par défaut | Oui | Ses opérations financières | Non |

L'accès super administrateur aux contenus d'une école n'est pas implicite. Les statistiques SaaS sont agrégées ; toute future fonction de support donnant accès aux dossiers scolaires demande une autorisation explicite et un audit. La suspension empêche les connexions et opérations de l'école, sans effacer ses données. Les membres d'une école suspendue ne peuvent plus utiliser des jetons déjà émis.

## Paiements et intégrité comptable

Une charge est une dette d'une inscription, d'une catégorie de frais et d'une échéance. Le solde est calculé à partir des charges et allocations effectives, jamais saisi manuellement. Un paiement possède une référence unique par école, une date, une méthode, un montant et un auteur. Les allocations à une ou plusieurs charges appartiennent au même élève et à la même école.

L'encaissement ouvre une transaction, verrouille les charges concernées, vérifie le reliquat, crée paiement/allocations/reçu/audit/événement d'envoi, puis commit. La clé `Idempotency-Key` empêche les doubles écritures lors des reprises réseau. Le MVP refuse les surpaiements sans workflow d'avoir. La numérotation des reçus est atomique par école et année ; un reçu émis n'est jamais réutilisé.

Un paiement confirmé ne se modifie ni ne se supprime. Une annulation autorisée produit une contre-écriture motivée, conserve le reçu original marqué annulé et recalcule le solde. Les rapports distinguent montant facturé, encaissements bruts, annulations et encaissements nets. Les revenus SaaS sont séparés des paiements de scolarité.

## Notes et bulletins

Les évaluations définissent matière, classe, période, note maximale et coefficient positif. La note est comprise entre zéro et le maximum ; l'absence d'une note est distincte d'un zéro. Une moyenne par matière normalise chaque note sur 20 et pondère par coefficient d'évaluation ; la moyenne générale pondère les matières par leurs coefficients. Le choix de traitement des notes manquantes, appréciations, rangs et mentions est configurable et doit être fixé par école avant publication.

La génération valide la complétude selon cette politique, fige les résultats, paramètres et données d'identité dans une version, et produit un PDF. Publier rend cette version accessible au parent autorisé et déclenche une notification. Une correction génère une nouvelle version auditable. Un lien public prévisible vers un fichier n'est pas autorisé : les liens utilisent un jeton aléatoire, une durée limitée et une révocation possible.

## WhatsApp et dépendances externes

L'adaptateur de livraison doit proposer `mock` pour le développement et `whatsapp_cloud` pour un envoi réel. Le mock marque les messages `simulated`, jamais `delivered`. L'envoi réel nécessite un compte professionnel Meta, un numéro activé, un jeton, un secret de webhook, des modèles approuvés et le consentement des tuteurs. Ces ressources ne sont pas fournies dans le PPT.

Les déclencheurs sont : absence enregistrée, note publiée, reçu/solde actualisé, rappel d'impayé, annonce et bulletin publié. La file outbox est écrite dans la transaction métier. Le worker envoie après commit, réessaie les erreurs temporaires, limite les doublons et expose les erreurs finales. Les webhooks vérifient l'authenticité, dédupliquent les événements et mettent à jour les statuts sans les faire régresser.

Les messages scolaires ne doivent pas contenir plus de données que nécessaire. Un numéro WhatsApp reçu ne suffit pas à donner accès à tous les élèves : tout échange entrant est rattaché à un tuteur vérifié et à ses seuls enfants. Une première version peut fonctionner par notifications sortantes et liens sécurisés ; un dialogue automatisé de consultation du solde nécessite aussi les contrôles d'identité et le routage par école.

## Exploitation et validation de livraison

Développement reproductible avec PostgreSQL, API, worker, web et variables documentées. Production : TLS, secrets hors dépôt, migrations versionnées, journalisation sans mots de passe/jetons, supervision des erreurs et de la file, sauvegardes quotidiennes avec essai documenté de restauration. Stockage local de PDF possible en développement ; stockage persistant privé requis en production. L'intégration WhatsApp réelle et la publication mobile/desktop dépendent de comptes externes, certificats et environnements de compilation.

Critères d'acceptation du premier MVP :

1. Un super administrateur crée une école, son abonnement et un administrateur, puis la suspend et la réactive.
2. L'administrateur crée année, périodes, matières, classe, enseignant, élève et tuteur, puis inscrit l'élève.
3. L'enseignant voit uniquement ses classes, son emploi du temps et ses devoirs ; il enregistre présence et note et retrouve ces données après reconnexion.
4. L'administrateur publie un bulletin PDF calculé à partir des notes persistées.
5. Le comptable crée des frais, enregistre deux paiements partiels, obtient les reçus et un solde correct ; une reprise identique ne double pas le paiement.
6. Les rappels, annonces et documents sont visibles dans un journal de communication avec statut explicite ; un test réel WhatsApp est requis avant d'annoncer cette intégration opérationnelle.
7. Les tests d'isolation, rôles, suspension, annulation financière et accès aux documents réussissent ; les flux sont exercés dans les clients web et Flutter disponibles.
8. Toute capacité simulée, intégration non configurée ou plateforme non compilée est signalée dans le bilan de livraison.
