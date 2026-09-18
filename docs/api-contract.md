# SRC SCHOOL — Contrat API cible v1

Statut : contrat de conception du MVP, à faire converger avec l'OpenAPI FastAPI lors de l'implémentation. Voir `architecture.md` pour les règles métier et l'isolation.

## Conventions

Base `/api/v1`, JSON UTF-8, identifiants UUID, dates `YYYY-MM-DD`, horodatages ISO 8601 UTC. Montants entiers en unité de devise (`amount: 25000`, `currency: "XOF"`). Notes décimales transmises comme chaînes pour préserver leur précision. Les listes utilisent `page`, `page_size` (maximum 100), filtres documentés et tri stable : `{ "items": [], "total": 0, "page": 1, "page_size": 25 }`.

Une création répond `201`, une lecture/modification `200`, une suppression réversible sans contenu `204`, un travail asynchrone `202` avec `job_id`. Erreurs : `{ "error": { "code": "SCHOOL_SUSPENDED", "message": "Établissement suspendu", "details": {} }, "request_id": "…" }`. Codes HTTP : `401` session absente/expirée, `403` droit absent/suspension, `404` ressource inconnue ou située hors école, `409` conflit/doublon/version périmée, `422` données invalides, `429` débit excessif.

Les endpoints `/schools/{school_id}/…` exigent une appartenance active à cette école et un rôle autorisé. L'identifiant de l'URL n'est pas une autorisation. Les super administrateurs utilisent `/platform/…` et n'ont pas automatiquement accès aux données scolaires.

Les mutations financières, publications et envois prennent `Idempotency-Key`. Même clé et même contenu renvoient le résultat initial ; contenu différent : `409 IDEMPOTENCY_CONFLICT`. Les objets modifiables portent `version` ; les modifications soumettent `expected_version` pour empêcher l'écrasement silencieux.

## Authentification

| Méthode et chemin | Description |
| --- | --- |
| `POST /auth/login` | Identifiant/mot de passe ; ouvre une session, rend utilisateur et appartenances |
| `POST /auth/refresh` | Rotation du jeton renouvelable et renouvellement de session |
| `POST /auth/logout` | Révoque la session courante |
| `GET /auth/me` | Utilisateur, écoles, rôles et permissions effectives |
| `POST /auth/password-reset/request` | Réponse neutre indépendamment de l'existence du compte |
| `POST /auth/password-reset/confirm` | Jeton à usage unique et nouveau mot de passe |

Le transport des secrets distingue les clients : cookies sécurisés pour le web avec protection CSRF ; bearer access token et refresh token en stockage sécurisé pour Flutter. Une école suspendue est contrôlée à chaque requête, y compris avec un jeton non expiré. La récupération réelle de mot de passe nécessite un canal d'envoi configuré ; aucun jeton de récupération n'est renvoyé au navigateur de production.

## Plateforme SaaS — super administrateur

| Méthode et chemin | Description |
| --- | --- |
| `GET /platform/dashboard` | Écoles actives/suspendues, élèves agrégés, abonnements et revenus SaaS enregistrés |
| `GET, POST /platform/schools` | Liste, création école et paramètres initiaux |
| `GET, PATCH /platform/schools/{id}` | Détail et paramètres de l'école |
| `POST /platform/schools/{id}/activate` | Activation auditée |
| `POST /platform/schools/{id}/suspend` | Suspension avec motif |
| `POST /platform/schools/{id}/administrators` | Crée ou rattache l'administrateur avec invitation ou activation sécurisée |
| `GET, POST /platform/plans` | Plans configurables |
| `PATCH /platform/plans/{id}` | Tarifs/limites, sans modifier les anciens paiements |
| `GET, POST /platform/subscriptions` | Liste et attribution d'un abonnement à une école |
| `PATCH /platform/subscriptions/{id}` | Plan, dates, état selon transitions validées |
| `POST /platform/subscriptions/{id}/payments` | Paiement SaaS manuel, idempotent et audité |
| `GET /platform/usage` | Statistiques agrégées par période |

## Gestion scolaire — préfixe `S = /schools/{school_id}`

| Méthode et chemin relatif | Description / rôle |
| --- | --- |
| `GET S/dashboard` | Indicateurs selon rôle et période, calculés depuis les données persistées |
| `GET, POST S/academic-years` | Liste/création année ; admin pour écriture |
| `GET, POST S/terms` | Périodes d'une année ; admin pour écriture |
| `GET, POST S/classes` | Classes ; enseignant limité à ses affectations |
| `GET, PATCH S/classes/{id}` | Détail et modification autorisée |
| `GET, POST S/students` | Élèves, recherche et filtres classe/année ; admin pour création |
| `GET, PATCH S/students/{id}` | Dossier, champs limités au rôle |
| `POST S/students/{id}/archive` | Archive le dossier sans supprimer les historiques |
| `GET, POST S/guardians` | Tuteurs, numéro normalisé, lien aux enfants |
| `PATCH S/guardians/{id}` | Coordonnées et liens, admin |
| `POST S/guardians/{id}/consents` | Consentement de communication, origine et date |
| `GET, POST S/enrollments` | Inscription élève/classe/année ; admin pour création |
| `PATCH S/enrollments/{id}` | Changement d'état contrôlé ; aucune réécriture des historiques |
| `GET, POST S/teachers` | Personnel enseignant et compte associé ; admin pour écriture |
| `PATCH S/teachers/{id}` | Profil et activation |
| `GET, POST S/subjects` | Matières et coefficients ; admin pour écriture |
| `GET, POST S/teaching-assignments` | Affectation enseignant/classe/matière/année |
| `DELETE S/teaching-assignments/{id}` | Fin d'affectation sans supprimer notes/pré­sences |
| `GET, POST S/timetable` | Créneaux ; enseignant lit son planning, admin écrit |
| `PATCH, DELETE S/timetable/{id}` | Modification/suppression créneau, contrôle des chevauchements |

## Pédagogie

| Méthode et chemin | Description |
| --- | --- |
| `GET, POST S/attendance-sessions` | Séances par classe, date et créneau |
| `PUT S/attendance-sessions/{id}/records` | Saisie en lot atomique ; admin ou enseignant affecté |
| `GET S/attendance` | Registre filtré par classe/élève/période |
| `GET, POST S/assessments` | Évaluations, maximum, coefficient et période |
| `PATCH S/assessments/{id}` | Modification avant publication/verrouillage |
| `PUT S/assessments/{id}/grades` | Notes en lot atomiques ; contrôle de l'affectation |
| `POST S/assessments/{id}/publish` | Publie les notes, génère notifications |
| `GET S/grades` | Notes autorisées et filtres |
| `GET, POST S/assignments` | Devoirs d'une classe/matière avec échéance |
| `PATCH S/assignments/{id}` | Texte, échéance, état |
| `PUT S/assignments/{id}/progress` | Suivi par élève : remis/non remis/évalué |
| `POST S/report-cards/generate` | Génération pour classe/période ou élève, retourne travail asynchrone |
| `GET S/report-cards` | Bulletins, versions et état de génération |
| `POST S/report-cards/{id}/publish` | Admin ; fige la version publiée et planifie communication |
| `GET S/report-cards/{id}/download` | PDF authentifié et autorisé |
| `POST S/report-cards/{id}/share-links` | Admin ; lien parent limité dans le temps et révocable |

Exemple de saisie :

```json
{
  "expected_version": 2,
  "records": [
    {"enrollment_id": "<uuid>", "status": "absent", "reason": null},
    {"enrollment_id": "<uuid>", "status": "present", "reason": null}
  ]
}
```

Les statuts possibles sont `present`, `absent`, `late`, `excused`. Une modification d'absence ne renvoie pas indéfiniment le même message : une clé d'événement identifie la transition et sa version. Les champs de note utilisent `score: "15.5"` ou `score: null`, jamais zéro pour représenter une note manquante.

## Finances — administrateur et comptable

| Méthode et chemin | Description |
| --- | --- |
| `GET S/finance/dashboard` | Facturé, encaissé net, impayés et taux de recouvrement |
| `GET, POST S/fee-definitions` | Catégories scolarité/cantine/transport et montants |
| `PATCH S/fee-definitions/{id}` | Modification pour futures charges |
| `GET, POST S/charges` | Dettes d'une inscription avec échéance |
| `POST S/charges/batch` | Facturation atomique d'une classe, idempotente |
| `GET S/students/{id}/account` | Charges, allocations, historique et solde |
| `GET, POST S/payments` | Liste et enregistrement transactionnel |
| `GET S/payments/{id}` | Détail, allocations, reçu et annulation éventuelle |
| `POST S/payments/{id}/reverse` | Contre-écriture avec motif obligatoire |
| `GET S/receipts/{id}/download` | PDF du reçu, contrôle école et rôle |
| `GET S/arrears` | Impayés par échéance/classe/élève |
| `POST S/arrears/reminders` | Enqueue rappels aux tuteurs consentants |
| `GET S/finance/reports` | Rapport par période, format JSON ou CSV |

Exemple `POST S/payments`, en-tête `Idempotency-Key: <uuid>` :

```json
{
  "student_id": "<uuid>",
  "amount": 25000,
  "currency": "XOF",
  "method": "cash",
  "paid_at": "2026-09-15T10:00:00Z",
  "external_reference": null,
  "allocations": [{"charge_id": "<uuid>", "amount": 25000}]
}
```

Réponse : `{ "payment_id": "<uuid>", "receipt_id": "<uuid>", "receipt_number": "2026-000001", "amount": 25000, "remaining_balance": 75000, "currency": "XOF", "status": "confirmed" }`.

La somme des allocations égale le montant. Les charges sont verrouillées pendant la validation ; une allocation supérieure au solde donne `409 OVERPAYMENT`. Les méthodes `cash`, `bank_transfer`, `mobile_money`, `other` décrivent le moyen reçu ; elles n'impliquent pas qu'un prestataire de paiement est intégré.

## Communications et documents

| Méthode et chemin | Description |
| --- | --- |
| `GET, POST S/announcements` | Brouillons, cible classe/école ; admin pour création |
| `POST S/announcements/{id}/send` | Planifie envois idempotents |
| `GET S/messages` | Journal : queued/sending/sent/delivered/read/failed/simulated |
| `POST S/messages/{id}/retry` | Reprise autorisée d'un échec, déduplication conservée |
| `GET S/notifications` | Notifications de l'utilisateur connecté |
| `POST S/notifications/{id}/read` | Marque sa notification lue |
| `GET S/jobs/{id}` | Progression/résultat d'une tâche de son école |
| `GET S/events` | Option SSE authentifiée ; événements limités au rôle et à l'école |
| `GET S/audit-events` | Audit filtré, admin uniquement |
| `GET /documents/shared/{token}` | Téléchargement par jeton opaque valide, sans exposition d'autres documents |
| `DELETE S/document-share-links/{id}` | Révocation du lien |
| `GET /integrations/whatsapp/webhook` | Vérification du webhook selon le protocole du fournisseur |
| `POST /integrations/whatsapp/webhook` | Signature vérifiée, déduplication et routage par compte/numéro configuré |

Les détails d'événements évitent les notes, données parentales et données financières quand un identifiant à recharger avec autorisation suffit. Un lien de bulletin n'est ni indexable ni conservé dans les journaux d'accès en clair. L'API de partage applique expiration et révocation à chaque accès.

## Contrôles d'intégration minimaux

- Deux écoles contenant des élèves distincts : toutes les routes de détail, lot, téléchargement et événements refusent les identifiants de l'autre école.
- Un enseignant ne saisit ni notes ni présences pour une classe non attribuée ; un comptable ne publie pas de bulletin.
- Deux requêtes concurrentes de paiement ne peuvent dépasser une charge ; un retry idempotent produit un seul reçu.
- Un paiement annulé garde son historique, libère le solde et apparaît correctement dans les rapports.
- Une école suspendue perd immédiatement l'accès métier ; réactivation préserve les dossiers.
- Un bulletin publié contient les bonnes moyennes et une version figée ; un lien expiré ou révoqué échoue.
- Une communication de développement reste `simulated` ; les accusés réels proviennent uniquement de webhooks vérifiés.
- Les tableaux de bord reflètent les écritures persistées et appliquent les mêmes filtres d'année et d'école que leurs écrans de détail.
