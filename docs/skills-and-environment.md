# Skills et environnement — contrôle du 15 septembre 2026

## Vérifiés

- `apple-design` : SKILL.md présent et lu dans `/Users/MACPRO/.codex/skills/apple-design/` ; références locales disponibles.
- `superdesign` : SKILL.md présent et lu dans `/Users/MACPRO/.codex/plugins/cache/openai-curated-remote/superdesign/0.6.0/skills/superdesign/`.
- CLI Superdesign v0.14.0 exécutable et authentifiée avec l’équipe Personal.
- Les fichiers SKILL.md de Next.js, shadcn et vérification sont également présents. Catalogue de session : React et déploiement disponibles. Leur fonctionnement n’a pas encore été testé dans SRC SCHOOL.

## État du poste

- Node v22.11.0 trouvé ; Python via pyenv trouvé.
- PostgreSQL 17 est installé et une instance temporaire locale a été initialisée pour la recette. Flutter 3.47.4 / Dart 3.13.3 (macOS arm64) est installé dans `/Users/MACPRO/develop/flutter` ; `flutter analyze`, `flutter test` et `flutter build web` passent. `flutter doctor` signale encore l’installation Xcode incomplète et les command-line tools Android manquants.
- Aucun code applicatif initial dans le workspace : seulement le PowerPoint et 11 captures.
- Aucune base PostgreSQL ni intégration WhatsApp configurée pour ce projet à ce stade.

## Étape de conception

Le workflow du skill Superdesign impose une maquette puis une validation avant le code applicatif. La maquette approuvée existe ; les six fichiers d’initialisation Superdesign ont maintenant été générés pour le code réel. Une tentative de récupération distante du draft a été interrompue après absence de réponse réseau ; aucune nouvelle direction n’a été inventée. Architecture, contrat API, recette et charte sont préparés pendant cette étape. Une maquette ne constitue pas un MVP fonctionnel.

Avant recette complète : ajouter Flutter au PATH du shell, installer les dépendances restantes, configurer les comptes de test et le fournisseur WhatsApp choisi, puis exécuter les parcours desktop/mobile.
