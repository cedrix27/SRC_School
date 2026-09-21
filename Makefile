FLUTTER_BIN ?= /Users/MACPRO/develop/flutter/bin/flutter

.PHONY: web-install web-build backend-test backend-migrate backend-seed flutter-analyze flutter-test flutter-web-build verify
web-install:
	cd apps/web && npm install
web-build:
	cd apps/web && npm run typecheck && npm run build
backend-migrate:
	cd backend && if [ -f .env ]; then set -a; . .env; set +a; fi; DATABASE_URL="$${DATABASE_URL:-postgresql+psycopg://src:src@127.0.0.1:5432/src_school}" .venv/bin/python -m app.migrate
backend-seed:
	cd backend && if [ -f .env ]; then set -a; . .env; set +a; fi; test -n "$${DEMO_PASSWORD}" && DATABASE_URL="$${DATABASE_URL:-postgresql+psycopg://src:src@127.0.0.1:5432/src_school}" .venv/bin/python -m app.seed
backend-test:
	cd backend && TEST_DATABASE_URL="$${TEST_DATABASE_URL:-postgresql+psycopg://src:src@127.0.0.1:5432/src_school_test}" .venv/bin/pytest -q
flutter-analyze:
	cd apps/flutter && $(FLUTTER_BIN) analyze
flutter-test:
	cd apps/flutter && $(FLUTTER_BIN) test
flutter-web-build:
	cd apps/flutter && $(FLUTTER_BIN) build web
verify: backend-test web-build flutter-analyze flutter-test flutter-web-build
