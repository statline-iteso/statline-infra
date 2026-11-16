# Backend plan

Back to the [roadmap](README.md). Repo: [statline-backend](https://github.com/statline-iteso/statline-backend).

## Built

- JSON Schemas per sport (SL-03), devcontainer and docker compose (SL-02)
- **api**: Express + Prisma, 12 entities with JSONB + GIN (SL-23), auth JWT/bcrypt and roles (SL-24), ligas/equipos with posiciones, calendario and forma (SL-25), jugadores/partidos with boxscore (SL-26), probes and Prometheus metrics (SL-22). 43 tests, 100 % line coverage.
- **ingesta**: `AdaptadorDeporte`, API-Sports client with retries and quota, NBA adapter (SL-19), JSON Schema validation (SL-15), idempotent Postgres upserts and run audit (SL-14), CLI per sport (SL-16), Dockerfile (SL-21). 28 unit + 2 integration tests.
- **predicciones**: FastAPI skeleton with probes and the request contract (SL-32), Dockerfile (SL-39).
- CI: lint, types, coverage ≥ 70 %, integration against PostgreSQL 16, three image builds, Trivy (SL-49, SL-52).

## Next

1. SL-18 NFL and SL-17 Liga MX adapters (copy the NBA pattern, record fixtures).
2. SL-27 player aggregates and comparison (JSONB queries).
3. SL-33 → SL-38 predictions: features, models, registry, `/generar`.
4. SL-28, SL-29, SL-30 remaining routes; SL-31 Redis.
5. SL-20 fallback providers.
