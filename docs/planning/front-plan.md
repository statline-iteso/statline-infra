# Frontend plan

Back to the [roadmap](README.md). Repo: [statline-frontend](https://github.com/statline-iteso/statline-frontend).

## Built

- Vite + React 18 + TS + Tailwind, lazy routes, layout, 404 (SL-40)
- API client with token refresh, TanStack Query, login/logout, protected routes (SL-41)
- Jugadores list with search, sport filter, pagination, detail (SL-42)
- Ligas standings and partidos by date (SL-43)
- nginx image, Vitest with coverage gate, CI with Trivy (SL-48, SL-50)

## Next

1. SL-44 boxscore view with Recharts (`/partidos/:id`, API ready).
2. SL-45 comparison (needs backend SL-27).
3. SL-46 forecasts and projections (needs SL-29 and predictions).
4. SL-47 watchlists and alerts (needs SL-28, SL-30).
