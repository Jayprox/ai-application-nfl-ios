# Chalk That NFL — iOS

A native SwiftUI iOS app for **Chalk That NFL**, an NFL stats/research/betting-insights app. This app is a second frontend client of the existing `ai-application-nfl` backend — the same backend the "web" app (a React app) already uses. It is a sister project to a similar app, Chalk That MLB iOS, built the same way.

If you're an AI assistant (or a person) picking this project up for the first time — whether continuing in Claude, or in ChatGPT, Cursor, Copilot, or anywhere else — this file plus `HANDOFF.md` are meant to get you fully oriented without needing anything else. Read this file first for the big picture, then `HANDOFF.md` for the detailed, chronological "why was it built this way" decision log and the current in-progress work.

## What this app is

Chalk That NFL (iOS) shows the same NFL data as the Chalk That NFL web app — games, teams, players, stats, betting odds, edge/rankings signals, prop lines, a research-assistant chat, and a "portfolio agent" that logs picks and tracks a leaderboard — in a native iOS interface instead of a browser.

**Hard rule for this project: this app never invents, derives, or estimates a number.** Every value on screen comes straight from the backend's API. If the backend doesn't return it, the app doesn't show it (or shows an honest empty/error state) rather than making something up. The goal is also to visually mirror the web app as closely as normal iOS conventions allow — same layout, same information, same badges/labels — not to redesign it.

This is a **frontend-only** project. The backend (`ai-application-nfl`, a separate repo) is a shared, deployed service also used by the real web app — it is never modified from this project without the owner (JD) explicitly asking for it.

## The backend it talks to

- Repo: `ai-application-nfl` (separate repo from this one, sibling folder).
- Live API: `https://backend-api-production-15ce.up.railway.app`
- Stack: Node.js + Express + PostgreSQL (`pg`), hosted on Railway.
- Auth: username/password login issuing a JWT access token + refresh token (`POST /login`, `POST /refresh`, `POST /logout`). Every other route requires that JWT.
- Data comes from real ingestion jobs (a background worker syncing rosters, schedules, odds, prop lines, etc.) into Postgres — this app just reads it back out over HTTP/JSON.
- Most non-auth routes return `{ data: ..., meta: ... }`; the JSON key casing is mostly `snake_case` (a few auth fields are `camelCase`) — see `Network/APIClient.swift`'s `JSONDecoder`/`JSONEncoder` setup for how that's bridged into idiomatic Swift.

## Tech stack (this app)

- Swift + SwiftUI, MVVM (a `ViewModel` per screen, `@Published` state, views are dumb).
- `URLSession` + `async`/`await` for all networking — no Combine-based networking, no third-party HTTP libraries.
- **Zero third-party dependencies** — everything is hand-rolled (networking, markdown rendering for chat, etc.).
- Minimum iOS 16.
- One central request wrapper, `Network/APIClient.swift` — every API call goes through it. It attaches the bearer token, and transparently refreshes-and-retries once on a 401 (deduped across concurrent callers by `TokenRefresher`, an `actor`).
- `Extensions/Color+Brand.swift` is the single source of truth for the app's design tokens (the "Stadium Lights" palette — canvas/surface/ink/accent/positive/negative/etc. colors). Any new UI should pull colors from there, never hardcode a hex value.
- `Extensions/Font+Brand.swift` defines the brand type scale (Inter/Oswald) — see "Known gaps" below, the actual font files aren't bundled yet so this currently falls back to the system font.

## Project layout

```
Chalk That NFL/
  Chalk_That_NFLApp.swift      — app entry point
  ContentView.swift            — root view (auth gate -> MainTabView)
  Views/MainTabView.swift      — the 4-tab shell: Board / Research / Agents / Record
  Extensions/                  — Color+Brand, Font+Brand, date/lenient-decoding helpers
  Network/                     — APIClient, Endpoints, KeychainManager, TokenRefresher
  Models/                      — one file per API resource's Decodable/Encodable wire models
  ViewModels/                  — one @MainActor ObservableObject per screen
  Views/<Feature>/             — one folder per feature area (Board, Games, Teams, Players,
                                  Props, Rankings, Edge, Portfolio, Picks, Leaderboard, Chat,
                                  Research, Agents, Record, Shared)
```

Xcode's file list is a `PBXFileSystemSynchronizedRootGroup` — it auto-discovers any file added under `Chalk That NFL/` on disk. New files don't need to be manually added to the `.xcodeproj`.

## App navigation shape

Four tabs, mirroring the web app's own navigation grouping (not the flatter one-tab-per-feature style of the sibling MLB app):

- **Board** — the home/front-door tab: this week's games, top edges, rankings leaders.
- **Research** — Games / Teams / Players, each with a list screen and a detail screen (one shared `NavigationStack` + one `ResearchRoute` enum drives all the pushes in this tab).
- **Agents** — Player Props + Odds, Rankings, Edge, Portfolio, and Chat (the research-assistant).
- **Record** — Picks (the portfolio agent's logged picks) and Leaderboard.

Each tab owns its own `NavigationStack`, so pushes in one tab don't affect another.

## Current status (as of 2026-09-24)

**Everything in the original build plan is built and wired to live data:** Auth → Games/Teams/Players (Research) → Board → Player Props+Odds → Rankings+Edge → Portfolio/Picks/Leaderboard → Chat. Beyond that, two "bring this screen to full parity with web" follow-up passes are also done: `GameDetailView` (odds, player stats, live box score, drive feed) and `PlayerDetailView` (insight cards + the 5-tab stat scope selector with filters). The app icon is done too (custom football/uptick-arrow/bar-chart artwork).

**Latest fix (2026-09-24): Teams detail blank screen resolved in simulator testing.** The initial state rendered an empty `Group`, so its `.task` never started and its navigation title never appeared. A permanent `VStack` now hosts the lifecycle modifiers. The earlier list/Section-nesting diagnosis was disproved; list flattening remains only as the existing presentation. The unchanged view reproduced the exact failure in an isolated simulator harness; the fixed source passed loading, empty/populated roster, error/retry, and roster-link checks. The full app builds with Xcode 26.5. Live authenticated API verification is still pending because this simulator has no signed-in session. See `HANDOFF.md` for evidence and limitations.

**Known, deliberate gaps (not bugs to fix, just flagged):**
- `Extensions/Font+Brand.swift` references Inter/Oswald but the `.ttf` files were never bundled into the target — falls back to the system font. Cosmetic only.
- `GameDetailView`'s Live Box Score and Drive Feed don't background-poll during an in-progress game, unlike web. No polling infrastructure exists yet and it hasn't been asked for.
- Admin-only actions (roster/schedule resync) are intentionally not reproduced anywhere in this app — out of scope, confirmed with JD early on.

**Build/test environment:** earlier development used a shell without Xcode. As of 2026-09-24 this Mac has Xcode 26.5 and an iOS 26.5 simulator; use them to build and test changes directly. `python3 scripts/check_balance.py` remains a cheap syntax-balance check, not a substitute for compilation. Simulator lifecycle tests can use isolated offline fixtures without touching the shared backend; live API checks require a signed-in app session.

## Where to look next

- **`HANDOFF.md`** — the full chronological build log: every phase, every bug found and fixed, every non-obvious backend quirk discovered (e.g. Postgres `NUMERIC` columns arriving as JSON strings, roster-status codes, freshness-window filters), and the live "in progress" section for whatever's currently being debugged. This is the file to read for *why* something is built the way it is, and it's kept up to date after every change — keep doing that.
- **`scripts/check_balance.py`** — run this (`python3 scripts/check_balance.py` from the repo root) after any Swift edit made outside Xcode, as a cheap sanity check before asking for a rebuild.
- The backend repo (`ai-application-nfl`, sibling folder) — read its `backend/routes/*.js` for the actual contract of any endpoint before assuming its shape; the frontend web app's `frontend/src/**` is also useful as the reference implementation this app is mirroring.
