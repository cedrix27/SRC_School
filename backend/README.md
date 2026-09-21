# API SRC SCHOOL

Python 3.12+, PostgreSQL 16+. Depuis `backend/` :

```sh
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
export DATABASE_URL='postgresql+psycopg://src:src@127.0.0.1:5432/src_school'
.venv/bin/python -m app.migrate
# Optionnel : définir DEMO_PASSWORD (10 caractères minimum), puis
.venv/bin/python -m app.seed
.venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8010
```

OpenAPI : `/docs`. Santé PostgreSQL : `/health`.

Les cookies web exigent `X-CSRF-Token` égal au cookie `src_csrf`. Flutter utilise le jeton `access_token` dans `Authorization: Bearer …`. Session révocable de 12 heures ; `/auth/refresh` effectue une rotation. Définir `COOKIE_SECURE=true` sous HTTPS, `CORS_ORIGINS` explicitement et `PUBLIC_API_URL` pour les liens PDF.

Le modèle initial utilise des agrégats JSON versionnés, isolés par établissement, avec validation serveur des références. Il ne prétend pas fournir les clés étrangères composites ni la RLS décrites dans l'architecture cible. Les paiements sont sérialisés par école dans PostgreSQL et ne sont modifiables que par contre-écriture. Les messages sont exclusivement `simulated` dans cette version ; aucun appel fournisseur n'est exécuté. Les PDF sont générés depuis les données persistées et les bulletins figent les résultats calculés. La politique actuelle exige toutes les notes pour les évaluations de la période ; moyennes pondérées sur 20, arrondi au centième.

Le schéma versionné est initialisé explicitement par `app.migrate`, jamais à chaque démarrage. Les comptes fictifs sont créés uniquement par `app.seed`, avec le mot de passe fourni par l'opérateur. Ne pas utiliser ce jeu de démonstration en production.

Tests : `TEST_DATABASE_URL=postgresql+psycopg://…/src_school_test .venv/bin/pytest -q`. Utiliser une base de test séparée, dont les tables sont recréées.
