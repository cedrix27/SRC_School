# SRC SCHOOL

SaaS de gestion scolaire multi-établissements SRC DIGITAL.

## État actuel

Première tranche MVP implémentée : API FastAPI/PostgreSQL, dashboard et CRUD web Next.js, client Flutter enseignant initial.

- [Première maquette administrateur](https://p.superdesign.dev/draft/9255e0cf-2d36-4f3e-bc3b-9a946d1d55bf)
- [Canvas du projet](https://superdesign.dev/teams/09fca93e-7be1-4bea-9c3e-4c446b438ff5/projects/276ae9a5-0240-4920-873c-0fc2c049b537)
- [Architecture](docs/architecture.md) et [contrat API](docs/api-contract.md)
- [Scénarios de recette](docs/mvp-acceptance.md) et [feuille de route multi-agent](docs/roadmap.md)
- [Charte](.superdesign/design-system.md), [revue design](docs/design-review.md), [skills et environnement](docs/skills-and-environment.md)

Validation exécutée : `backend/.venv/bin/pytest -q` → 5 tests PostgreSQL réussis ; `apps/web/npm run typecheck` et `npm run build` réussis ; `apps/flutter/flutter analyze`, `flutter test` et `flutter build web` réussis. WhatsApp reste en mode `simulated` tant que les identifiants Meta et modèles approuvés ne sont pas configurés.

## Stack décidée

Next.js admin/superadmin web ; Flutter desktop admin/comptable et mobile enseignant ; FastAPI et PostgreSQL communs. Parents via WhatsApp.

## Reprendre le travail

Lire `AGENTS.md` puis les références pertinentes de `design/`. La première maquette attend une validation visuelle selon le workflow Superdesign ; l’architecture et le contrat décrivent les fonctionnalités à implémenter, pas des endpoints déjà disponibles.

Pour lancer : consulter `backend/README.md`, définir `DATABASE_URL`, exécuter `make backend-migrate`, puis `DEMO_PASSWORD='...' make backend-seed`; démarrer l’API avec `cd backend && .venv/bin/uvicorn app.main:app --port 8000`, et le web avec `cd apps/web && npm run dev`.
