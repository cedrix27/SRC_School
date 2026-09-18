# SRC SCHOOL — consignes durables

## Produit et stack

- Source fonctionnelle : `SRC_SCHOOL_Presentation (1).pptx`, complétée par les décisions de l’utilisateur.
- Web administrateur école et super administrateur : Next.js / TypeScript.
- Desktop administrateur et comptable, mobile enseignant : Flutter / Dart.
- Backend métier unique : Python / FastAPI. Base métier : PostgreSQL.
- Parents : WhatsApp dans le MVP, sans application parent supplémentaire.
- Français et FCFA par défaut. Ne pas présenter les tarifs indicatifs du PPT comme validés.

## Design — à chaque intervention visuelle

1. Consulter `design/` et ouvrir les captures pertinentes AVANT toute création ou modification d’écran.
2. Lire `.superdesign/design-system.md` et `docs/design-review.md`. Citer les captures consultées dans le compte rendu du travail.
3. Les références locales priment sur les suggestions génériques des outils. Préserver les originaux.
4. Utiliser les skills installés `apple-design` et `superdesign` selon le besoin et les instructions utilisateur. Lire leurs instructions avant application.
5. Réutiliser les mêmes tokens de couleur, typographie, espacement et états dans Next.js et Flutter ; adapter la navigation à la plateforme.
6. Vérifier lisibilité, clavier, libellés accessibles, zoom/texte agrandi, petit écran, chargement, erreurs et absence de données.
7. Ne pas recopier les noms, téléphones, conversations ou la marque Denteva des captures dans les jeux de données SRC SCHOOL.

## Organisation multi-agent demandée par l’utilisateur

- Coordinateur : décisions partagées, architecture, intégration, revue et livraison.
- Agent backend : FastAPI, PostgreSQL, migrations, authentification, isolation des écoles, finances, PDF et intégrations.
- Agent web/design : Next.js admin/superadmin, charte et parcours.
- Agent Flutter : clients desktop/mobile et expérience propre aux appareils.
- Agent recette : tests des parcours, sécurité, accessibilité et préparation du pilote.
- Respecter la limite de sessions simultanées de l’environnement ; faire tourner les rôles par lots.
- Attribuer des fichiers distincts et partager le contrat API avant des implémentations parallèles.
- Les agents sont lancés pendant les sessions de travail ; ces consignes ne constituent pas des services permanents.

## Qualité et définition de terminé

- Suivre `docs/mvp-acceptance.md`, `docs/architecture.md` et `docs/api-contract.md`.
- Contrôler rôle et établissement côté API, y compris les objets liés et les exports. Ne jamais faire confiance à un identifiant d’école reçu du client.
- Transactions et idempotence pour paiements ; montants exacts ; audit des actions sensibles.
- Les statistiques doivent venir de la base. Les données de démonstration restent explicitement identifiées.
- Ne pas annoncer un message WhatsApp livré sans preuve fournisseur ni un build Flutter testé sans exécution.
- Aucun secret dans le dépôt ou les sorties d’outils. Configuration externe via variables d’environnement.
- Une livraison fonctionnelle nécessite les parcours complets, PostgreSQL réel, tests d’isolation, PDF et vérification des intégrations configurées.
