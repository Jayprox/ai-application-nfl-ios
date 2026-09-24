# Chalk That NFL iOS — Handoff

Living handoff doc for this repo, following the same convention as the
Chalk That MLB iOS app's `CODEX-HANDOFF.md` (one main doc here, small
scoped per-feature request docs later if a screen needs its own). Read
this first if you're picking this project back up in a new session.

## Read this first — where things stand (updated 2026-09-24)

If you're a new chat picking this project up cold, this section is the
whole state of the world in one place. Everything below it is the
detailed, chronological decision log (useful for "why was it built this
way," not required reading to get oriented).

**What this is, in one paragraph:** a native SwiftUI iOS app for
"Chalk That NFL," a second client of the existing `ai-application-nfl`
backend (same one `web`, the React app, already uses — live at
`https://backend-api-production-15ce.up.railway.app`). Frontend-only:
the backend is never modified, and nothing here invents or derives a
number the API doesn't already return — every screen mirrors web's own
data and, as closely as iOS conventions allow, web's own layout.
Swift/SwiftUI/MVVM, `URLSession` + `async`/`await`, zero third-party
dependencies, min iOS 16. Sister app to Chalk That MLB iOS, same
architecture pattern, different backend/domain.

**Build status: the entire original build order is done, and both
follow-up parity phases are done too.**
Auth → Games/Teams/Players → Board → Player Props+Odds →
Rankings+Edge → Portfolio/Picks/Leaderboard → Chat — every tab and
screen in that list is real and wired to live API calls. Beyond that
original scope, JD then asked (2026-09-21) to bring `GameDetailView` up
to full parity with web's `GameDetailPage.jsx`, which added the four
sections it was missing: full per-bookmaker Odds, Player Stats (season
avg/total, both rosters), Live Box Score (per-game stats + Top
Performers), and Drive Feed. Two real bugs turned up once JD started
clicking through that build and are already fixed: an iOS-17-only API
used in Drive Feed's play-by-play text (crashed the build), and player
names in the 8-column Defense/Punt-Return/Kick-Return tables wrapping
one letter per line (fixed by giving the shared stat table a
horizontally-scrolling layout instead of squeezing everything into the
screen width). Then (2026-09-22) JD asked to bring `PlayerDetailView` up
to full parity with web's `PlayerDetailPage.jsx` too — the "MATCHUP"-
style insight cards (`GET /insights/players/:id`) plus the 5-tab stat
scope selector (Season Avg/Season Total/Last 5/Career/Game Log), season
+ home-away/time-slot/weather filters, StatGrid, and Game Log table, all
backed by `POST /query`. That's also done — see the new decisions
section below. The full app now builds with Xcode 26.5 (2026-09-24); this does not by itself verify every live-data screen.

**What's actually planned / not started:** nothing new is queued;
the Teams blank-screen bug is resolved, with simulator verification and
JD's confirmation that the fix works (2026-09-24). One small cosmetic
item is still open from scaffolding: `Extensions/Font+Brand.swift`
references Inter/Oswald but the actual `.ttf` files were never bundled
into the target (falls back to the system font). The app icon is done
(2026-09-23, see below).

**Resolved — Teams blank screen (confirmed by JD, 2026-09-24).**
The unchanged `TeamDetailView` reproduced JD's exact symptom: one body
log, no `load` call, no request, no title. Its initial false/nil/nil
state produces an empty `Group`; the lifecycle modifiers attached to
that empty group never run. Replacing the root with a permanent
`VStack(spacing: 0)` makes `.task` run and content appear. This was
verified before editing the app, using the actual view/view-model
source in an isolated offline simulator harness. Prior claims below
that `Section` nesting was the root cause are superseded and incorrect.
The final source also passed error/retry, empty/populated roster, and
player-link checks. Temporary Teams prints are removed. The full app
build succeeds. JD subsequently confirmed, "yup that worked," closing
the reported blank-screen issue. Codex's own runtime checks used offline
fixtures; the rebuilt real app showed Login in its simulator session.
See the 2026-09-24 investigation entry for full evidence and confirmation.

**Known, deliberate (not a gap to "fix"):** `GameDetailView`'s Live Box
Score and Drive Feed don't background-poll while a game is
`in_progress`, unlike web's own polling for those two — there's no
polling infrastructure on this screen yet and JD hasn't asked for it,
so it's flagged rather than silently missing. Admin sync routes
(`POST /admin/sync-roster`/`sync-schedule`) are out of scope for this
app entirely, confirmed with JD early on — web doesn't expose them
either.

**Process, for whoever's driving this next:** this Mac has Xcode 26.5
and an iOS 26.5 simulator. Build and test directly when possible; the
older shell-only caveats below describe the original development
environment. Run `python3 scripts/check_balance.py` after Swift edits,
but use a real Xcode build for type/availability checks. Keep this
current-state section and the chronological log updated. Do not modify
the shared backend without JD's permission.

## What this is

Native SwiftUI iOS client for Chalk That NFL — a second client of the
existing `backend-api` (repo: `ai-application-nfl`), same as `web`.
Frontend-only: no backend changes made or anticipated. Full spec and
rationale lives in `chalk-that-nfl-ios-brief.md` (pasted into the
kickoff conversation, not committed to this repo) — this doc tracks
what's actually been decided/built since then.

## Decisions made while scaffolding (2026-09-19)

- **Bundle ID:** `rookiegame.Chalk-That-NFL`, matching the MLB app's
  `rookiegame.Chalk-That` convention. Change in Signing & Capabilities
  if you want something else.
- **Development Team:** reused `7BK4R85P5E` from the MLB app's project
  (same account) so the project signs immediately in Xcode. Not a
  secret, just a convenience — change it in Signing & Capabilities if
  this should be a different team.
- **Deployment target: iOS 16.0** — per the build brief, not the MLB
  app's actual 17.0 (that app was built later against a newer Xcode;
  the brief explicitly asked for 16 here).
- **Base URL:** `https://backend-api-production-15ce.up.railway.app`
  (from `ai-application-nfl`'s own README "API:" line). Point
  `Endpoints.baseURL` at `http://localhost:<PORT>` for local backend
  dev.
- **Auth deliberately does NOT copy the MLB app's `APIClient`/
  `AuthViewModel`.** The MLB app uses one static JWT with no refresh
  flow (delete-on-401 only). This backend does real access+refresh
  rotation with revoke-on-replay
  (`ai-application-nfl/docs/architecture.md` §4.7), and the brief
  explicitly asked to mirror *web's* smarter pattern instead:
  `TokenRefresher` (an actor) dedupes concurrent refreshes exactly like
  `frontend/src/api/client.js`'s "concurrent 401s share a single
  in-flight refresh call," and `APIClient.request` retries a 401 exactly
  once after a successful refresh, dropping to login
  (`.chalkThatNFLSessionExpired` notification → `AuthViewModel`) if the
  refresh itself fails.
- **No `GET /me` equivalent exists on this backend** (unlike MLB's
  `/api/auth/me`). `KeychainManager.username` is just a local echo of
  what the person typed at login, for display only — not a mirror of
  any server value.
- **JSON casing:** backend-api mixes camelCase auth fields
  (`accessToken`) with snake_case data fields (`entity_type`,
  `sample_size`). `JSONDecoder.chalkThatNFL` /
  `JSONEncoder.chalkThatNFL` apply `.convertFromSnakeCase` /
  `.convertToSnakeCase` globally — safe because that strategy only
  touches keys that actually contain an underscore — so every Swift
  model stays plain camelCase. Use these two, not a bare
  `JSONDecoder()`/`JSONEncoder()`, for anything new.
- **Admin sync triggers (`POST /admin/sync-roster`,
  `/admin/sync-schedule`) are explicitly OUT of scope for this app** —
  confirmed with JD 2026-09-19. Web doesn't expose them either; they
  stay an ops-only API surface.
- **Navigation mirrors web's own IA, not MLB's tab layout.**
  `frontend/src/components/Layout.jsx` + `NavGroup.jsx` group web's 9
  non-Board routes into Research / Agents / Record, with Board
  standalone as the front door. `MainTabView` copies that grouping
  (4 tabs) rather than MLB's flat one-tab-per-feature shape, since
  matching *this app's own* web IA fits the brief's "mirror the web app"
  mandate better than copying MLB's specific tabs.
- **Fonts not bundled yet.** `Extensions/Font+Brand.swift` calls
  `.custom("Inter", ...)` / `.custom("Oswald", ...)`, but the actual
  `.ttf` files still need to be added to the target (drag into the
  project, list under Info.plist's "Fonts provided by application") —
  until then SwiftUI silently falls back to the system font. Grab the
  same files `web`'s `index.html` Google Fonts link uses.
- **App icon not designed yet** — `Assets.xcassets/AppIcon.appiconset`
  has an empty single-size slot ready for artwork.

## Build order (from the brief, confirmed 2026-09-18/19)

Auth → Games/Teams/Players → Board (home) → Player Props + Odds →
Rankings + Edge → Portfolio/Picks/Leaderboard → Chat. Admin: excluded.

## Decisions made building Games/Teams/Players (2026-09-19)

- **`players.status` is a real uppercase roster code (ACT/CUT/DEV/RES/
  INA/RET/EXE), not the lowercase words
  `frontend/src/constants/playerStatus.js` assumes.** Confirmed against
  `routes/teams.js`/`routes/players.js`'s actual SQL filters,
  `TeamDetailPage.jsx`'s working `status === 'RES'` check, and
  `scripts/fantasy-auction-values.js`'s `ROSTER_STATUS_LABEL` (the
  authoritative label map: ACT → no label, CUT → "cut", DEV → "practice
  squad", RES → "reserve/IR", INA → "inactive", RET → "retired", EXE →
  "exempt list"). `playerStatus.js` looks like stale/dead code in web
  itself — `Models/PlayerStatus.swift` implements the real codes, not
  that file's assumption.
- **Roster grouping mirrors `constants/rosterPositions.js` exactly**
  (`Models/RosterPositions.swift`) — QB/RB/WR/TE/OL, DL/LB/CB/S, K/P/LS,
  not the coarser offense/defense/special_teams split.
- **Grouped sections use a real `Identifiable` struct
  (`Models/KeyedGroup.swift`), not a labeled tuple + `id: \.label`** —
  keypaths into tuple labels aren't reliably supported across Swift
  versions and this couldn't be compile-tested here; not worth the risk
  of a second failed build cycle over a cosmetic type choice.
- **Research tab is one shared `NavigationStack`, rooted in
  `ResearchHomeView`, routed through one `ResearchRoute` enum**
  (`Views/Research/ResearchRoute.swift`) rather than each screen
  (Games/Teams/Players) declaring its own nested `NavigationStack` or
  several `navigationDestination(for: String.self)` registrations —
  game ids and player ids are both `String`, so those would collide.
- **Deliberately NOT built this pass** (flagging so nothing looks
  forgotten):
  - `GameDetailView` shows schedule/weather/injuries only — no boxscore
    (`GET /games/:id/boxscore`) or season player-stats
    (`GET /games/:id/player-stats`). Both return rich per-position stat
    columns that are a meaningfully separate modeling effort from the
    rest of this pass.
  - `PlayerDetailView` shows bio/injury only — no stat tabs (Season
    Avg/Last 5/Career/Game Log via `POST /query`). That route's response
    shape varies by position group and scope, which is real, separate
    work (dynamic Codable handling), not a quick add-on.
  - `TeamDetailView` does NOT reproduce web's "Resync rosters" button
    (`POST /admin/sync-roster`) — admin sync triggers are out of scope
    for this app entirely (confirmed with JD 2026-09-19).
  - `GamesListView`/`GameRowView` don't show Edge or Odds badges yet —
    those routes aren't wired until the Rankings+Edge and Player
    Props+Odds phases.
- **Not build-verified** — same caveat as Auth: hand-written from a
  shell without Xcode/swiftc, checked for balanced braces/parens and a
  couple of risky Swift patterns fixed defensively, but the real test is
  Xcode. Please build and report back before more gets layered on.

## Build fixes applied (2026-09-19)

Two build failures reported after the Games/Teams/Players pass, both
fixed:

- **"Invalid redeclaration of 'accent'"** in `Color+Brand.swift`. The
  asset catalog's `AccentColor` colorset auto-generates `Color.accent`
  (`ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS`),
  which collided with a manually-declared `static let accent`. Fix:
  removed the manual declaration; `Color.accent` now comes solely from
  the asset catalog (already set to the brand orange).
- **"Build Failed | 27 issues"** after adding the Games/Teams/Players
  ViewModels, two causes:
  1. `TeamsViewModel`, `TeamDetailViewModel`, `PlayersViewModel`,
     `PlayerDetailViewModel`, `GamesViewModel`, `GameDetailViewModel`
     only had `import Foundation`, missing `import Combine` — required
     for `@Published`/`ObservableObject` to resolve (same as
     `AuthViewModel`, which already had it and built fine). Fix: added
     `import Combine` to all six.
  2. The project's `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` build
     setting (copied from the MLB project, which has no real `actor`
     types) conflicted with `TokenRefresher`, a genuine Swift `actor`.
     That setting made `TokenRefresher`'s methods main-actor-isolated,
     so its internal calls to `KeychainManager`'s static properties and
     `JSONEncoder.chalkThatNFL`/`JSONDecoder.chalkThatNFL` failed with
     "Main actor-isolated ... cannot be accessed from outside of the
     actor." Fix: removed `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;`
     from both the Debug and Release target configs in
     `project.pbxproj`. Safe because every ViewModel is already
     explicitly `@MainActor`, and SwiftUI Views/App are main-actor by
     framework default regardless of this project setting — only
     `TokenRefresher` needed real actor isolation, which it now has.

Not build-verified beyond brace/paren balance checks (same caveat as
everything else built from this shell) — please rebuild and confirm.

## Runtime issues fixed after first successful build (2026-09-19)

JD reported three things after the build succeeded:

- **Games tab: "Couldn't read the server's response... isn't in the
  correct format."** Real bug. `games.weather_temp_f` and
  `weather_wind_mph` are Postgres `NUMERIC` columns with no `::float8`
  cast in `games.js` — the `pg` driver returns `NUMERIC` as a JSON
  *string* ("72.5"), not a number, to avoid float-precision loss. The
  `Game` model declared them as plain `Double?`, so `JSONDecoder` threw
  a type mismatch on every `/games` response. Fix: added
  `Extensions/Decoding+Lenient.swift` (a `KeyedDecodingContainer`
  helper that accepts either a JSON number or a numeric JSON string) and
  gave `Game` a custom `init(from:)` that uses it for
  `weatherTempF`/`weatherWindMph`/`weatherWindDirectionDeg`. Property
  types didn't change, so `GameRowView`/`GameDetailView` needed no
  edits. Flagging for later phases: odds prices and prop lines are
  likely `NUMERIC` too (not yet confirmed) — reuse this helper there
  instead of re-diagnosing the same bug.
- **Teams: selecting a team showed a blank page.** Not a crash — a
  missing empty state. `GET /teams/:id` filters the roster to
  `status IN ('ACT','RES')` AND `updated_at` within the last 2 days AND
  at least one recorded stat row (same as `players.js`'s search) —
  legitimate reasons a team's roster can come back empty right now
  (e.g. `sync_roster` hasn't ticked recently in production, or genuinely
  early-season). Web's `TeamDetailPage.jsx` handles this with "No
  roster on file for this team."; the iOS `TeamDetailView` had no
  equivalent, so an empty roster rendered as nothing below the team
  header. Fix: added that same message as a Section when
  `rosterByPosition` is empty — matches web exactly rather than
  inventing new copy.
- **Players: bio shows, but no stats — expected.** This is by design,
  not a bug: `GET /players/:id` deliberately only returns identity/bio
  (see that route's own header comment), and `PlayerDetailView`
  already says so ("Season, last-5, career, and game-log stats are
  coming in a follow-up"). Confirmed via JD's own screenshot — Aaron
  Rodgers' bio card rendered correctly. No change needed.

## Resolved — Teams blank page (2026-09-20)

JD rebuilt with the debug instrumentation from the section this
replaces and confirmed Teams now works. No console output was needed
to confirm it — root cause wasn't conclusively pinned down (most
likely either a stale build before the earlier fixes, or the roster
freshness window genuinely clearing up between attempts), but the
underlying fixes from the "Runtime issues fixed" section above
(lenient NUMERIC decoding, empty-roster message) are confirmed working
end to end now.

Cleanup done: removed the `TeamDetailView` DEBUG red-text fallback
branch and the `[TeamDetailViewModel]` print statements added to chase
this down. Deliberately KEPT `APIClient.request`'s `#if DEBUG` request/
response logging (status code, byte count, body preview, decode
errors) — it's generic (not Teams-specific), compiled out of Release
builds, and will save time diagnosing whatever comes up in later
phases (Props/Odds, Rankings/Edge) rather than re-adding it each time.

## Decisions made building Board (2026-09-20)

Composes GET /games/current-week, GET /games, GET /edge (only_
disagreements=true), GET /odds, and GET /rankings (pinned to
passing_yards, limit=5) — same five fetches as BoardPage.jsx, each with
its own loading/error state except odds (silent overlay, same as web —
a failed odds fetch just means no OddsBadge, never its own error UI).

- **New models**: `OddsModels.swift` (`BookmakerLine`/`GameOdds` —
  every price/point column is NUMERIC-as-string, decoded via
  `Extensions/Decoding+Lenient.swift`), `EdgeModels.swift` (`EdgeRow`/
  `EdgeLean` — no lenient decoding needed here, edge.js explicitly
  `Number()`-coerces every numeric field before responding, and its two
  early-return shapes just omit keys rather than nulling them, which
  Swift's synthesized `Decodable` already handles for `Optional`
  properties), `RankingModels.swift` (`RankingRow` — `score`/
  `season_avg` are NUMERIC, lenient-decoded; `breakdown` JSONB isn't
  modeled, Board doesn't show it).
- **`EdgeBadge`/`OddsBadge`** added to `Views/Shared/Badges.swift`,
  ported from EdgeBadge.jsx/OddsBadge.jsx. `OddsBadgeLogic` (pure
  functions, no SwiftUI) does the DraftKings-only filtering and the
  pregame-combined-badge vs. post-final-per-market-grading split, kept
  separate from the `OddsBadge` View so the arithmetic is easy to check
  without also reasoning about ViewBuilder. One simplification: web
  renders "DK" as its own bold sub-span before each badge's text; this
  port folds it into one `Text` per chip rather than composing an
  `AttributedString`, since that was easy to reason about by hand and
  the bold-DK/rest split is a minor typographic detail, not a data
  difference.
- **`BoardGameCardView`** (Board-only, not a change to
  `Views/Games/GameRowView.swift`) — GameCard.jsx's content plus the
  Edge/Odds badges GameRowView deliberately still omits.
  `GamesListView`'s full schedule doesn't fetch edge/odds yet — that's
  intentionally still deferred to the Player Props+Odds / Rankings+Edge
  phases (see GamesViewModel's own comment); once those land, revisit
  whether `GameRowView` should just take optional edge/odds params
  instead of keeping two card views.
- **Board tab gets its own `NavigationStack`** with the same
  `.navigationDestination(for: ResearchRoute.self)` switch
  `ResearchHomeView` uses (same route enum, reused as a plain
  `Hashable` value type — nothing stack-specific about it). Each
  `TabView` tab is its own independent navigation flow in SwiftUI, so
  this is the idiomatic way to let Board's "Full schedule" link and its
  game/player cards push GamesListView/GameDetailView/PlayerDetailView
  without touching Research's own stack.
- **"Top Edges" and "Rankings Leaders" have no "view all" link yet** —
  web links to /edge and /rankings, which don't exist as iOS screens
  until the Rankings+Edge phase. Board still shows the curated top-5
  preview list either way; only the section header's link is missing
  for now.
- **Live score polling** (BoardPage.jsx's `useEffect` +
  `useApiFetch(gamesPath, { pollMs })`, ~10 min while any game is
  in_progress) ported as a `Task`-based loop in `BoardViewModel`
  (`updatePolling()`/`stopPolling()`), silently reloading just the
  games list without flashing the loading state — cancelled in
  `BoardView`'s `.onDisappear` rather than left running forever.
- **Not build-verified** — same caveat as every other phase: hand-
  written from a shell with no Xcode/swiftc, checked for balanced
  braces/parens only. Please build and report back.

## Decisions made building Player Props + Odds (2026-09-20)

- **Props lives under a real Agents tab now**, not a ComingSoon
  placeholder. Web groups Rankings/Props/Edge/Portfolio/Chat under one
  "Agents" nav dropdown (frontend/src/components/Layout.jsx's
  AGENTS_ITEMS) — mirrored with a new `AgentsHomeView` (same "list of
  NavigationLinks into one shared route enum" shape `ResearchHomeView`
  already established), with a new `AgentsRoute` enum of its own
  (`.props`, `.gameDetail`, `.playerDetail`) rather than reusing
  `ResearchRoute` — Agents' own destinations (Rankings/Edge/Portfolio/
  Chat, as they're built) are conceptually separate from Research's,
  even though `.gameDetail`/`.playerDetail` happen to duplicate two
  cases. Rankings/Edge/Portfolio/Chat show as disabled "Coming soon"
  rows in the same list rather than leaving the whole tab as one
  placeholder, so the tab is honest about what's actually built.
- **`line`/`over_price`/`under_price` needed the same lenient decoding**
  as game odds — `player_prop_odds.line`/`over_price`/`under_price` are
  NUMERIC(6,1)/NUMERIC(7,2) with no server-side cast (confirmed against
  `db/migrations/012_player_prop_odds.sql`), same NUMERIC-as-string
  situation `Decoding+Lenient.swift` was already built for.
  `final_value`/`context.recent_avg`/`context.td_rate`/`edge_pct`, by
  contrast, are all explicitly `Number()`-coerced server-side
  (`backend/routes/props.js`'s `attachContext`/`leanFromAverage`/
  `leanFromTdRate`) — real JSON numbers, decoded as plain `Double`/`Int`
  with no lenient decoding needed. Documented field-by-field in
  `PropModels.swift`'s own header comment so this isn't re-diagnosed a
  third time.
- **Centralized the ISO8601-fractional-seconds fix into one place**
  (`Extensions/BackendDate.swift`) instead of writing a third copy of
  the two-formatter fallback dance — `Game.kickoffDate` and
  `OddsBadgeLogic.latestDK()` (both fixed in the Board verification
  pass just above) were refactored to use it too, and Props' own
  `synced_at`/kickoff-time parsing uses it from the start.
- **`gradeProp()`/`LEAN_BADGE`/`GRADE_VARIANT`/`leanSortKey()` ported as
  a pure `PropGradingLogic` enum** (`Views/Props/PropGrading.swift`),
  same "logic separate from the View" split `OddsBadgeLogic` already
  uses — the void/scored/no_td/push/over/under distinction is modeled
  as a `PropGrade` enum with a `tone` (positive/negative/neutral)
  rather than a shared color string, so an Under can't accidentally
  render with the same color as an Over the way web's own pre-fix
  version once did (see that bug's own history in PropsPage.jsx's
  comments) — the enum makes that mistake structurally impossible here.
- **`line` formats with a fixed 1 decimal place** (`String(format:
  "%.1f", ...)`), matching NUMERIC(6,1)'s canonical string form exactly
  — web never re-formats `prop.line` for display (just interpolates the
  raw value straight into JSX), so this preserves exact parity (e.g.
  "74.5", "288.0") rather than an iOS-native trimmed-decimal look.
  `final_value`/games-played, by contrast, are already real integers
  server-side and format with no decimal, matching web's own
  interpolation of those fields.
- **No manual week picker** — same as web's PropsPage.jsx, Props always
  just shows the resolved current week (`GET /games/current-week`), no
  prev/next controls like Games has.
- **Player taps push through `PlayerDetailView`, but without web's
  `?scope=last5` query param** — that param only pre-selects a stat tab
  on web's player page, and iOS's `PlayerDetailView` doesn't have stat
  tabs yet (deliberately deferred, see Games/Players section above).
  Navigation parity, not full feature parity — nothing here fakes data
  the tab doesn't have yet.
- **Not build-verified** — same caveat as every other phase: hand-
  written from a shell with no Xcode/swiftc, checked for balanced
  braces/parens only. Please build and report back.

## Decisions made building Rankings + Edge (2026-09-20)

- **Rankings and Edge are both real tabs now** under Agents (only
  Portfolio/Chat remain "Coming soon" rows). `AgentsRoute` grew
  `.rankings`/`.edge` cases, same pattern `.props` already established.
- **Rankings' stat-category/season pickers use explicit action methods**
  (`setStatCategory`/`setSeason`, mutate-then-reload — same shape
  `GamesViewModel.setSeason` already uses) rather than a reactive
  `didSet`, specifically to avoid a double-fetch when those same
  properties are ALSO being set programmatically during the initial
  `GET /games/current-week` seed. The free-text week field, by contrast,
  genuinely needs `PlayersViewModel`-style debounce (raw keyboard input,
  not a discrete picker action) — an `isSeeding` guard suppresses that
  debounce specifically during the initial seed so `loadInitial()`'s own
  explicit `load()` call is the only fetch on first launch. Same pattern
  used in `EdgeViewModel` for its own week field.
- **Week is optional for Rankings (blank = whole-season top N, matching
  `/rankings`'s own optional week param) but required for Edge** (`/edge`
  400s without one; web's own EdgePage.jsx shows "Enter a week to see
  that week's games." instead of fetching) — `Endpoints.rankings()` took
  a `week: Int?` for this (Board's own call site, which always passes a
  real week, still compiles — Swift promotes a plain `Int` to `Int?` at
  the call site with no change needed there).
- **`RankingsResponse`/`RankingsMeta`/`RankingsFreshness` added** (not
  the shared `APIEnvelope<T>`) specifically because
  `meta.freshness.synced_at` (when `matchup_scores` was last computed)
  is real, server-only information the footer displays — same reasoning
  `PropsResponse` already used for its own meta. Edge's list meta
  (`{ count }`) needed no equivalent, since `count` is always just
  `results.length` — trivially `edges.count` client-side, no new model
  needed there.
- **`GET /edge/games/:gameId` reuses the existing `EdgeRow` model
  wrapped in the plain `APIEnvelope<EdgeRow>`** — confirmed
  `compareGameEdge()`'s return shape is identical to each row
  `listEdges()` already returns (same fields, same missing-vs-null
  handling for the early-return cases), so no new model was needed.
- **`GameDetailView` gained a "Model vs. Market" section** (between the
  header and Injuries, matching `GameDetailPage.jsx`'s own section
  order), fetched as a third, independent, best-effort read in
  `GameDetailViewModel.load()` — separate from the `game`+`injuries`
  critical pair, same "don't block the whole screen on an optional read"
  principle `PropsViewModel.loadGames()` already established. A missing
  or failed edge lookup falls back to "Edge read not available yet for
  this game.", same as web.
- **Explicitly NOT built: `GameDetailView`'s full per-bookmaker Odds
  section** (`GET /odds/games/:id`, every bookmaker across
  spreads/h2h/totals/team_totals). This is genuinely separate work from
  Edge — its own market-grouping/bookmaker-display-name/point-formatting
  logic, none of which Board's DK-only `OddsBadge`/`OddsChip` reuses —
  and squarely outside what "Rankings + Edge" as a phase name implies.
  Flagged here rather than silently built or silently skipped; worth its
  own small follow-up phase whenever you want it.
- **Edge's list rows are deliberately not tappable** — confirmed web's
  own `EdgePage.jsx` `<li>` has no `<Link>` wrapping the game row at all
  (unlike Props/Board's game cards), so this mirrors that exactly rather
  than adding a push-to-game-detail affordance web itself doesn't have.
- **Signal badge (Rankings) and EdgeBadge/PropBadgeChip's neutral-state
  handling** — reused the existing `EdgeBadge` View from the Board phase
  as-is for the Edge tab (already correctly modeled the "no signal"
  solid-`surface2` case, same shape `PropBadgeChip`'s own fix needed
  during the Props verification pass). Rankings' own Signal pill has no
  such "no read at all" case to special-case — web's `signalBadgeClass`
  always has a real 0-4 value, so every state gets the tinted-12%-
  opacity treatment uniformly.
- **Not build-verified** — same caveat as every other phase: hand-
  written from a shell with no Xcode/swiftc, checked for balanced
  braces/parens only. Please build and report back.

## Decisions made building Portfolio/Picks/Leaderboard (2026-09-20)

- **Portfolio lives under Agents, Picks+Leaderboard live under a new
  Record tab** — mirrors web's own `Layout.jsx` grouping exactly
  (`AGENTS_ITEMS` includes Portfolio; `RECORD_ITEMS` is Picks+
  Leaderboard). `AgentsRoute` grew a `.portfolio` case (same pattern
  `.rankings`/`.edge` already established); a brand-new `RecordRoute`/
  `RecordHomeView` pair (identical shape to `AgentsRoute`/
  `AgentsHomeView`) replaces `MainTabView`'s old Record `ComingSoonView`
  placeholder outright, since both its screens are real now.
- **Portfolio is a real, user-facing write action, not an admin
  trigger** — confirmed against `PortfolioPage.jsx`'s own header
  comment: the portfolio agent (`POST /portfolio/slate`) already existed
  server-side with zero frontend surface until web's own Part 2 Phase 3
  added this page. Built it exactly as web has it: two distinct buttons
  (Preview slate = `dry_run=true`, no write; Build & log slate =
  `dry_run=false`, real write to `picks_log`) rather than one action
  gated by a checkbox — matches web's own reasoning for why it's two
  buttons, not one.
- **`APIClient` gained a second, no-body `post<T: Decodable>(_:
  authenticated:)` overload** — every endpoint so far either had no body
  (`GET`) or a real JSON body (`POST /login` etc.), but `POST /portfolio/
  slate` puts its whole request in the query string with no body at
  all. Added the overload rather than encoding an empty struct as a fake
  body.
- **`pick_id` (picks_log's BIGSERIAL primary key) is modeled as
  `String`, not `Int`** — confirmed node-postgres returns Postgres int8/
  BIGSERIAL as a JSON string by default (same precision-safety reasoning
  as the NUMERIC-as-string situation `Decoding+Lenient.swift` already
  documents), and neither `routes/picks.js` nor `lib/portfolio.js` wraps
  it in `Number()` anywhere. `PortfolioSlateItem.pickId` is `String?`
  (nil on a dry-run preview — `buildSlate()` only attaches it once a
  pick is actually inserted); `PickRow.pickId` is a non-optional
  `String` (`GET /picks` only ever returns already-persisted rows).
- **Only `PickRow` needs lenient decoding; `PortfolioSlateItem`/
  `PicksStats`/`LeaderboardEntry` don't** — confirmed by re-reading each
  route's handler directly rather than assuming the pattern holds
  everywhere: `routes/picks.js`'s `GET /picks` SELECT casts none of
  `predicted_line`/`units`/`confidence`/`actual_value` (real NUMERIC
  columns, no `::float8`/`Number()`), so `PickRow` uses the same custom
  `init(from:)` + `decodeLenientDoubleIfPresent` pattern as `PropRow`/
  `RankingRow`. Every OTHER numeric field touched in this phase (POST
  /portfolio/slate's `unit_size`/`model_margin`/`units`, GET /picks/
  stats's counts and `hit_rate_pct`, GET /leaderboard's counts and
  `hit_rate_pct`) IS explicitly `Number()`-wrapped server-side, so those
  three model files are plain synthesized `Decodable` — no custom init
  anywhere in them. Documented the reasoning inline in each file's own
  header comment so this doesn't need re-deriving later.
- **Leaderboard's HTML table becomes a row list, not a scrolling table**
  — web renders `#`/Agent/Record/Hit Rate/Pending/Total as a literal
  `<table>`; at phone width that's not a real iOS reading pattern, so
  `LeaderboardRowView` uses the same "row card" shape `RankingRowView`/
  `EdgeRowView` already established elsewhere in this tab group — rank
  + agent name + hit rate get the primary visual weight (same priority
  web's own column order implies), record/pending/total fold into a
  caption line underneath. Every underlying number/field is still
  displayed; only the layout shape changed to fit the screen.
- **`PortfolioFormat.number(_:)`** (in `PortfolioView.swift`) is the
  same "no trailing .0 for a whole number" JS-Number-to-string
  formatting `OddsBadgeLogic.formatNumber` already established —
  reused (via a small private `Endpoints.formatUnitSize` copy, to avoid
  the Network layer depending on a Views-layer type) so a whole-number
  unit size round-trips to the query string the same way web's own
  `String(unitSizeInput)` would.
- **Not build-verified** — same caveat as every other phase: hand-
  written from a shell with no Xcode/swiftc, checked for balanced
  braces/parens only. Please build and report back.

## Decisions made building Chat (2026-09-20)

- **Chat is the fifth and final Agents-tab screen** (`AgentsRoute.chat`)
  — this completes the full build order (Auth -> Games/Teams/Players ->
  Board -> Player Props+Odds -> Rankings+Edge -> Portfolio/Picks/
  Leaderboard -> Chat). `AgentsHomeView`'s `comingSoonRow()` helper is
  gone now too — every row under Agents is a real `NavigationLink`, no
  "Coming soon" placeholders left anywhere in the app.
- **Wire model kept separate from the UI model** — `ChatWireMessage`/
  `ChatRequest` exist purely for `POST /chat`'s `{messages: [{role,
  content}]}` request and `{data: {role, content}}` response shape;
  `ChatMessage` (with a local `UUID` for `Identifiable`/`ForEach`, plus
  a `ChatRole` enum instead of a bare string) is what the View actually
  renders. Neither needs lenient decoding — `role`/`content` are always
  plain strings, never a NUMERIC column.
- **Ported one web quirk deliberately, not "fixed" it**: sending a
  message trims the VISIBLE conversation itself to the last 12 entries
  (`ChatViewModel.maxHistory`, matching `MAX_HISTORY` on both
  `ChatPage.jsx` and `routes/chat.js`) — not just what's sent to the
  server — but the assistant's reply is then appended WITHOUT
  re-trimming, so the count can briefly sit one over 12 until the next
  send. That's exactly what web's own `setMessages(next)` /
  `setMessages(prev => [...prev, res.data])` sequence does, so it was
  ported as-is rather than quietly cleaned up — this is a visual/
  behavioral mirror, not a chance to improve on web's own logic.
- **No new persistence** — same as web, the conversation lives only in
  `ChatViewModel`'s in-memory state and is gone once the tab is backed
  out of or the app relaunches. No local caching, no draft restoration.
- **`ChatMarkdown` is a pure, from-scratch port of `ChatPage.jsx`'s
  hand-rolled markdown renderer** (kept in its own file, same "pure
  logic separate from View" precedent as `OddsBadgeLogic`/
  `PropGradingLogic`), covering the same deliberately narrow scope web
  does — bold spans, bullet/numbered lists, simple GFM-style pipe
  tables — because that's genuinely all the model ever reaches for (see
  web's own header comment on why this exists instead of a real
  markdown library: no new dependency needed to be `npm install`ed
  before it could be tested). Explicitly flagged in this file's own
  header as a best-effort rendering aid, not a data-parity concern the
  way every other model in this app is: the reply TEXT is always
  identical to what the API returned either way, so a rare mismatch
  from web's exact regex behavior on unusual input (e.g. a literal
  unmatched `**`) only affects how that text is visually chunked, never
  what it says.
- **Tables render as a horizontally scrollable row grid**, not literal
  HTML `<table>` markup obviously, but same layout intent as web's own
  `overflow-x-auto` wrapper — a header row (semibold, bottom-ruled) plus
  data rows, each cell a minimum width so narrow numeric columns don't
  starve a long team-name column.
- **Not build-verified** — same caveat as every other phase: hand-
  written from a shell with no Xcode/swiftc, checked for balanced
  braces/parens only. Please build and report back.

## Decisions made building GameDetailView full parity — Odds/Player
Stats/Live Box Score/Drive Feed (2026-09-21)

JD sent a screenshot of the actual web app's GameDetailPage (Lions @
Bills, 31-41 Final) and asked to mirror it fully. Read GameDetailPage.jsx
in its entirety (741 lines) plus the backend routes/schema it calls,
rather than assume the existing "Model vs. Market"/Injuries sections'
shape extended to the rest of the page — several assumptions from that
research were wrong on a first pass and corrected before writing code;
noted below so the same mistakes aren't repeated on a future page.

- **Odds section** (`GameOddsSection.swift`) — every synced bookmaker/
  market for this one game, narrowed to the same five majors web itself
  narrows to (BetMGM/DraftKings/FanDuel/Bovada/Caesars), grouped by
  market in `spreads → h2h → totals → team_totals` order, empty markets
  dropped. `OddsModels.swift`'s existing `BookmakerLine`/`GameOdds`
  already covered this response shape (including lenient NUMERIC
  decoding) from an earlier, unused read — no model changes needed.
  One subtlety worth flagging: `total_point` is the ONE odds field web
  never runs through `Number()` before display (every other price/point
  field is) — it's shown as Postgres's own NUMERIC(5,1) string,
  verbatim. Reused `PropGradingLogic.formatLine`'s `%.1f` for that field
  specifically (`formatRawPoint`), and a new `formatPoint` (trimmed via
  `PortfolioFormat.number`, "+"-prefixed if positive) for every other
  field — conflating the two would have shown `total_point` with a
  trailing ".0" trimmed off, which Postgres never actually sends.
- **Shared `StatCategoryTable<Row>` view** (`Views/Games/
  StatCategoryTable.swift`) — one generic table, fed column lists and
  per-row formatting closures, reused by BOTH the Live Box Score and
  Player Stats sections below — mirrors web's own single
  `BoxScoreCategoryTable` component being reused unchanged for both
  (confirmed via that component's own header comment), instead of
  writing up to six near-duplicate table views. Player-name links use a
  DESTINATION-based `NavigationLink` (`NavigationLink { PlayerDetailView
  (...) } label: {...}`), not a value-based one against a shared route
  enum — GameDetailView is reachable from three different
  NavigationStacks with three different route-enum types (Board's own
  stack, ResearchHomeView's `ResearchRoute`, AgentsHomeView's
  `AgentsRoute`), and a value-based link would silently no-op under
  whichever two don't declare a matching `.navigationDestination(for:)`.
- **Live Box Score section** (`GameBoxScoreSection.swift`,
  `BoxScoreModels.swift`) — per-team toggle over THIS game's actual
  played stat lines (`GET /games/:id/boxscore`), a "Top Performers"
  leaders strip, then Passing/Rushing/Receiving/Kicking/Punting/
  Defense/Punt Return/Kick Return tables in that order. Checked every
  offense/defense/special-teams column's actual Postgres type directly
  against `db/schema.sql` rather than assuming a uniform pattern from
  the Props/Odds phases' NUMERIC-as-string precedent: every column
  there is a plain INT (arrives as a real JSON number) EXCEPT
  `player_defense_game_stats.sacks` (NUMERIC(3,1), partial-credit sacks
  like 0.5) and `player_special_teams_game_stats.punt_avg`
  (NUMERIC(4,1)) — those two, and only those two, need
  `decodeLenientDoubleIfPresent`. Top Performers ports web's
  `teamLeaders()`/`topByStat()` exactly: per Passing/Rushing/Receiving,
  the offense row with the max yards for that category, excluded
  entirely if that max is `<= 0`, with the ", N TD" suffix appended only
  when the TD count is JS-truthy (i.e. `> 0`, not just non-nil — web's
  `{td && ...}` treats a real 0-TD game as falsy too). The section
  header always renders; the empty-state copy branches on
  `game.status` ("Box score available once the game kicks off." while
  scheduled, "No box score synced yet for this game." otherwise) — this
  needed a second pass after an initial draft used a generic "N lines ·
  synced Nm ago" footer copied from Props/Rankings, which isn't what
  this page actually shows (see next bullet).
- **Freshness footer is an ABSOLUTE clock time here, not a relative
  bucket** — `GameDetailPage.jsx`'s own `formatSyncedAt()` (same name as
  Props'/Rankings' function, genuinely different implementation) renders
  `toLocaleTimeString('en-US', {hour:'numeric', minute:'2-digit'})`
  (e.g. "3:45 PM"), and the footer text reads "Box score as of {time}" /
  "Drives as of {time}", only shown at all when `freshness.synced_at` is
  present — no sample-size count in either footer, unlike Props'. Added
  `RelativeTime.clockTimeLabel(_:)` alongside the existing
  `sinceSynced`/`sinceComputed` for this, rather than inventing a
  competing relative-time helper elsewhere. Caught this by re-reading
  the actual JSX line-by-line instead of pattern-matching from the
  Props/Rankings footer convention, which would have been a real
  (if minor) parity miss.
- **Player Stats section** (`GamePlayerStatsSection.swift`,
  `PlayerSeasonStatsModels.swift`) — both rosters' SEASON stats (not
  this-game stats), with its OWN independent team toggle and Season Avg/
  Season Total mode toggle (deliberately separate state from Live Box
  Score's own toggle, matching web). Confirmed by re-reading the JSX
  that this section renders the SAME eight categories as Live Box Score
  (Punt Return/Kick Return included) via the shared
  `ALL_BOX_SCORE_CATEGORIES` list — an earlier draft wrongly assumed
  only six categories (dropping the two return categories) from the
  section's name alone; fixed after checking the actual
  `ALL_BOX_SCORE_CATEGORIES.map(...)` call. Every stat column here is
  explicitly cast `::float8` server-side (no lenient decoding needed,
  unlike Live Box Score's two columns above). Display precision is a
  deliberate CHOICE, not a parity requirement worth flagging: web
  renders these raw floats completely unformatted (`{r[key] ?? 0}`),
  which for a Postgres `AVG()` can be a long ugly float; Season Avg mode
  rounds to one decimal (`%.1f`) and Season Total mode trims a whole
  number's trailing ".0" (`PortfolioFormat.number`) instead of
  reproducing that raw-float artifact — this changes how the number
  LOOKS, never the number a query returned. This section has NO
  freshness footer at all (confirmed against the JSX — not an
  oversight).
- **Drive Feed section** (`GameDriveFeedSection.swift`,
  `DriveModels.swift`) — `GET /games/:id/drives` rendered most-recent-
  drive-first (`[...drives].reverse()`), each drive card highlighted
  (`Color.positive` border/tint) when `is_scoring_play`, with its
  `play_details` rendered as `{ordinalDown(down)} & {distance} at
  {possessionText} — {text}` when `start.down != null`, else just
  `{text}` — down/distance/possessionText come straight off the
  vendor's own JSONB payload, nothing computed. `drive_id` is a plain
  SERIAL/INT4 here (confirmed against `014_drive_events.sql`) — unlike
  `picks_log.pick_id`'s BIGSERIAL-as-string quirk from the Portfolio
  phase, this one really does arrive as a JSON number, so no lenient
  decoding needed anywhere in this model. Same absolute-clock-time
  footer convention as Live Box Score ("Drives as of {time}"), same
  status-branched empty-state copy pattern.
- **`GameDetailViewModel`** now fetches five reads total beyond game+
  injuries (edge, odds, boxscore, player-stats, drives), every one of
  them independent and best-effort via `try?` — a missing/failed read
  never blocks the rest of the screen, it just falls back to that
  section's own empty state, same principle the edge fetch already
  established last phase. Boxscore/drives don't poll while the game is
  live (web reuses its header fetch's `livePollMs` for both) — there's
  no polling infrastructure on this screen to hook into yet and JD
  didn't ask for it, so this is flagged here as a deliberate, scoped-
  down gap rather than something silently dropped.
- **Not build-verified** — same caveat as every other phase: hand-
  written from a shell with no Xcode/swiftc, checked for balanced
  braces/parens only (81 Swift files, all balanced). Please build and
  report back — this is a big phase (8 new files, 3 modified) touching
  the single most complex screen in the app so far.

## Build fix — GameDriveFeedSection availability error (2026-09-21)

JD's first build of the GameDetailView full-parity phase failed with one
real error (plus two pre-existing, unrelated warnings in AuthViewModel
about mutating actor-isolated properties from a Sendable closure --
those predate this phase and weren't touched):

- **`'foregroundStyle' is only available in iOS 17.0 or newer`**, in
  `GameDriveFeedSection.swift`'s `playLine(_:)`. Root cause: that
  function builds a `Text` by hand (`var text = Text("")`, later
  `text + Text(play.text ?? "")`) so it can style just the down/distance
  prefix differently from the play text -- and `+` concatenation only
  works between two `Text` values, so the compiler has to keep `text`'s
  type as exactly `Text` all the way through. `Text` itself declares a
  `foregroundStyle(_:) -> Text` overload (for per-run styling within
  concatenated text) that's iOS 17+ only, distinct from the generic
  `View.foregroundStyle(_:) -> some View` modifier (iOS 15+) used
  everywhere else in this app -- and because `text` is pinned to the
  concrete `Text` type here, the compiler picks the iOS-17-only
  overload instead of the widely-available one. Fixed by switching both
  calls in that function to `.foregroundColor(_:)`, which has always
  returned `Text` since iOS 13 -- matching the pattern already used
  correctly in every other Text-concatenation spot in the app
  (`PortfolioView.swift`'s pick-summary line, `PicksView.swift`'s
  matchup line). Not a systemic bug: every other `.foregroundStyle`
  call in the app is on a `Text` used as a plain View (not concatenated
  or re-assigned to a `Text`-typed variable), so the compiler resolves
  those to the generic iOS-15+ modifier fine as-is -- checked for any
  other `Text + Text` construction in the app and found none using
  `.foregroundStyle`.
- This is exactly the class of bug the shell-only balance checker can't
  catch (it's a real type-checker/availability error, not a brace/paren
  mismatch) -- flagging as a reminder that "balanced" only means the
  file will get as far as the type checker, not that it'll pass it.

Re-verified all 81 Swift files still balanced after this fix. Please
rebuild.

## Fix — Defense table names wrapping character-by-character (2026-09-21)

JD sent a screenshot: in the Live Box Score's Defense table (8 stat
columns — SOLO/AST/SACK/INT/PD/FF/FR/TD), player names like "Aidan
Hutchinson" or "Christian Izien" were rendering one letter per line
instead of on a single line, then compared it against the actual web
app's own Defense table (screenshot of GameDetailPage itself, not
Yahoo's app as first mentioned) where every name sits on one line.

Root cause: `StatCategoryTable`'s name column used
`.frame(maxWidth: .infinity)` to soak up whatever space was left after
the fixed-width stat columns (40pt each). For a 3-4 column table
(Passing, Rushing, ...) that leaves plenty of room; for Defense's 8
columns (320pt of fixed width alone) it left almost nothing on a phone
screen, and SwiftUI's `Text` — handed a frame only a few points wide —
wraps character-by-character rather than word-by-word. Web never hits
this because its own `BoxScoreCategoryTable` wraps each table in its
own `overflow-x-auto` div (confirmed against the JSX) and lets the
browser auto-size columns to their actual content, scrolling
horizontally once the table is wider than the viewport.

Fixed by matching that same idea rather than just picking a slightly
wider fixed width (which would have just moved the breakpoint to a
longer name, not fixed the underlying issue): the name column now gets
a fixed 132pt width (generous enough for essentially any real player
name on one line, with `.lineLimit(1)` + tail truncation as a backstop
for the rare exception) and the whole header+rows block sits in its own
`ScrollView(.horizontal, showsIndicators: false)`. A 3-4 column table
still fits the screen with no visible scrollbar; the 8-column Defense
table now scrolls sideways instead of crushing the name column — same
end result as web's own per-table `overflow-x-auto`, adapted to
SwiftUI's fixed-width-column model. This is the one shared
`StatCategoryTable` view, so the fix applies to every category in both
Live Box Score and Player Stats at once, not just Defense.

Re-verified all 81 Swift files balanced. Please rebuild and check the
Defense (and Punt Return/Kick Return, which use the same table) tables
specifically.

## Decisions made building PlayerDetailView stat tabs + matchup card (2026-09-22)

JD sent a screenshot of web's actual `PlayerDetailPage.jsx` (Bijan
Robinson, RB) showing a "MATCHUP" insights card, a 5-tab scope
selector, a season dropdown, three split filters, a stat list, and a
footer, with the explicit instruction "Update the ios version to match
the web version." Researched both backend routes and every relevant
frontend file in full before writing any Swift (`routes/query.js`,
`lib/stats-query.js`, `routes/insights.js`, `lib/insights.js`,
`PlayerDetailPage.jsx`, `PlayerInsights.jsx`, `statColumns.js`,
`splits.js`, `EmptyStatsMessage.jsx`, `useStatsQuery.js`).

- **Two backend routes, deliberately separate.** `POST /query`
  (`Models/PlayerQueryModels.swift`) is the shared stats engine behind
  the 5 scope tabs — `season`/`season_total`/`last5`/`career` return one
  flat, position-group-shaped aggregate object; `game_log` returns an
  array of raw per-game rows. `GET /insights/players/:id`
  (`Models/PlayerInsightModels.swift`) is a genuinely different,
  separate endpoint for the 4 deterministic matchup/recent-form/
  situational/role-trend labels — confirmed against both route files'
  own header comments that this split is intentional ("no predictive
  calculations" in /query), not something to merge client-side.
- **Six explicit Decodable structs, not a dynamic dictionary decode.**
  3 aggregate row types + 3 game-log row types (one pair per
  `position_group`), same proven pattern as
  `PlayerSeasonStatsModels.swift`/`BoxScoreModels.swift` rather than a
  `[String: Double]` dynamic decode — there's no way to compile-check
  Swift in this shell, and a silently-wrong dynamic-key-casing bug would
  violate this app's one hard rule (never show invented/wrong data)
  with no build error to catch it. See that file's header for the full
  reasoning.
- **Aggregate scopes vs. game_log scope need different NUMERIC
  handling**, same distinction BoxScoreModels.swift/
  PlayerSeasonStatsModels.swift already established: `season`/
  `season_total`/`last5`/`career` cast every column `::float8` server-
  side (real JSON numbers, no lenient decoding needed), but `game_log`
  selects raw uncast columns, so only there do `defense.sacks`
  (NUMERIC(3,1)) and `special_teams.punt_avg` (NUMERIC(4,1)) need
  `decodeLenientDoubleIfPresent`.
- **Two distinct, separately-verified numeric display conventions** —
  confirmed against the exact JSX rather than assumed uniform:
  `StatGrid` values show whole numbers as plain integers and non-whole
  numbers at exactly 1 decimal place (`PlayerQueryDisplay.statGridValue`
  — its own rule, not the same as `PortfolioFormat.number` or
  `GamePlayerStatsSection`'s `statText(_:)`); `GameLogTable` shows RAW
  values with no reformatting (an Int column as-is; the two lenient
  NUMERIC columns via `%.1f`, which reproduces Postgres's own scale-1
  string form exactly, trailing zero included).
- **`PlayerStatColumns`/`PlayerSplitOptions`/`PlayerStatScopes`** in
  `PlayerQueryModels.swift` are this app's one copy of
  `statColumns.js`/`splits.js`/`PlayerDetailPage.jsx`'s `SCOPES` —
  verified line-for-line against those files, used to build both
  StatGrid's entries and GameLogTable's column headers so they can't
  drift apart from each other.
- **Stale-response protection, two layers.** `PlayerStatsSection`
  drives `PlayerDetailViewModel.fetchStats(...)` via SwiftUI's
  `.task(id:)`, keyed to every query-relevant field (player, scope,
  season, all 3 filters) — matches `useStatsQuery.js`'s own
  `bodyKey`-driven `useEffect`, and SwiftUI's built-in task cancellation
  stops a redundant in-flight request when the key changes.
  `fetchStats` additionally guards every `@Published` write with a
  monotonically increasing generation counter, mirroring
  `useStatsQuery.js`'s own `latestBodyKeyRef` comment: don't trust
  "started first" to mean "finishes first" if an older request's
  network response happens to land after a newer one's.
  `PlayerDetailViewModel.swift`'s header has the full reasoning.
- **`EmptyStatsMessage.jsx`'s 4-branch copy** ported verbatim as
  `PlayerStatsEmptyMessage.text(...)` (career-with-zero-games / active-
  split-narrowed-to-nothing / the-2026-season-hasn't-been-played /
  generic "no games that season") — not paraphrased.
- **Insights card tone/label logic** (`PlayerInsightDisplay` in
  `PlayerInsightModels.swift`) ported line-for-line from
  `PlayerInsights.jsx`'s `CATEGORY_LABEL`/`POSITIVE_LABELS`/
  `NEGATIVE_LABELS`/`formatLabel` — exact label vocab per category
  confirmed against `lib/insights.js` directly (e.g. matchup is
  `FAVORABLE_MATCHUP`/`TOUGH_MATCHUP`/`NEUTRAL_MATCHUP`, not guessed).
  The tone-badge Color mapping in `PlayerStatsSection.swift` follows
  `Badges.swift`'s existing `EdgeBadge` pattern. The whole card section
  renders nothing when every category comes back `label: null`, same
  as web's own "don't fake a reading" convention.
- **Insights use the live season, not the stats tabs' season.**
  `PlayerInsights.jsx` computes everything relative to a player's
  *next scheduled game*, independent of whatever historical season
  someone's browsing stats for — so `load(playerId:)` always requests
  `Endpoints.playerInsights(_:season: PlayerDetailViewModel.currentSeason)`
  regardless of `PlayerStatsSection`'s own `season` `@State`, matching
  that component's own header comment on why it's decoupled.
  `currentSeason`/`availableSeasons` on `PlayerDetailViewModel` follow
  the same per-ViewModel `static let` convention already used by
  `EdgeViewModel`/`PortfolioViewModel`/`RankingsViewModel`.
- **Same `Text`/`Button` locale-grouping comma bug as the Board
  verification pass (see that section below) turned up here too, JD-
  reported via screenshot** (`2,026 season` in the season picker
  instead of `2026`). Root cause identical: `Button("\(year) season")`
  and `Text("\(row.week)")`/`Text("\(viewModel.statsSampleSize) game...")`
  interpolate a raw `Int` directly into a `LocalizedStringKey` literal,
  which applies locale-aware grouping separators. Fixed with the same
  explicit `String(...)` conversion pattern used everywhere else in the
  app: `Button("\(String(year)) season")`, `Text(String(row.week))`,
  `Text("\(String(viewModel.statsSampleSize)) game...")`. Note that
  `filterLabel("\(season) season")` did NOT need this fix -- `filterLabel`
  takes a plain `String` parameter, so that interpolation resolves to
  `String`'s own interpolation (no locale formatting), not
  `LocalizedStringKey`'s -- confirmed by checking `filterLabel`'s
  signature rather than assuming every interpolation site was affected.
- **New files:** `Models/PlayerQueryModels.swift`,
  `Models/PlayerInsightModels.swift`,
  `Views/Players/PlayerStatsSection.swift`. **Modified:**
  `ViewModels/PlayerDetailViewModel.swift` (added the insights fetch and
  the full `fetchStats` flow), `Views/Players/PlayerDetailView.swift`
  (replaced the "coming in a follow-up" placeholder with
  `PlayerInsightsSection` + `PlayerStatsSection`), `Network/
  Endpoints.swift` (added `.query` and `.playerInsights(_:season:)`).

Verified all 84 Swift files still balanced via
`python3 scripts/check_balance.py` after these changes. Not yet build-
verified — please rebuild in Xcode and check: the matchup cards show
(when a player has signal), all 5 scope tabs load real data, the season
selector hides for Career, the three filters + Clear work, and Game Log
renders a horizontally-scrollable per-game table.

## App icon (2026-09-23)

I generated 6 candidate icon concepts from the app's own brand tokens
(`Color+Brand.swift`) for JD to choose from -- 4 in a "football + uptick
arrow" family mirroring Chalk That MLB's own ball-and-trend-line icon,
one chalkboard/play-diagram concept, and one goalpost concept. Checked
all 6 at actual home-screen icon sizes (180/120/60/40pt) before sending,
which flagged the chalkboard concept as illegible that small (too much
fine detail) -- called that out rather than letting JD find out after
building it in.

JD instead supplied his own final artwork: a photorealistic football
with a red uptick arrow and green bar chart on a dark navy background.
That source image was an "icon mockup" render, not a raw usable
asset -- it had the rounded-square icon shape and a drop-shadow/glow
inset within a larger square canvas, with visible background bleeding
around the rounded corners. Used as-is, this would have shown a double
border once iOS applied its own corner mask on top. Fixed by:
1. Detecting the mockup's inner content bounding box (scanning
   brightness along the horizontal/vertical centerlines to find where
   the outer gradient background transitions into the icon's own dark
   interior).
2. Cropping inward past that rounded corner's own curvature (verified
   visually across a few insets) so the crop's four corners land
   entirely within the icon's flat interior, not the rounded frame.
3. Applying a soft per-corner vignette (a radial multiply blend toward
   a sampled deep-navy tone, feathered so there's no hard edge) to
   neutralize any last trace of the outer background glow right at the
   very corner pixels.
4. Resizing to exactly 1024x1024, RGB with no alpha channel (a
   transparent or alpha-carrying icon is rejected by Xcode/App Store).

Wired into `Assets.xcassets/AppIcon.appiconset/` as `AppIcon-1024.png`,
referenced via a `filename` key added to that folder's `Contents.json`
-- this project already used the modern single-size app icon format (one
1024x1024 universal image; Xcode/iOS generate every other required size
from it), confirmed by reading the existing `Contents.json` before
assuming which format applied.

Verified all 84 Swift files still balanced after this change (this
phase touched no Swift, but re-ran the check as routine practice).

## Investigating — Teams detail page fully blank (2026-09-23)

> Historical investigation: the Section/List root-cause claims in this
> entry were disproved on 2026-09-24. See the verified investigation
> below; keep these attempts only as a record of what was tried.

JD reported the Teams detail screen (Research > Teams > select any team)
renders completely blank -- not even the header card or nav title, just
the back chevron and tab bar. This is a step further than the
2026-09-20 "Resolved" entry above, which was specifically the
empty-roster case (that one still showed the team header + "No roster
on file" text). A fully blank `Group` in `TeamDetailView` is only
reachable when `isLoading == false && errorMessage == nil && team ==
nil` -- i.e. the view is rendering in the gap before `.task` calls
`load(teamId:)`, or `load` never runs to completion. That default-false
`isLoading` pattern is shared by every ViewModel in the app (checked:
Auth/Edge/GameDetail/Games/Leaderboard/Picks/PlayerDetail/Players/
Portfolio/Props/Rankings/Teams all initialize `isLoading = false`), so
it's not unique to Teams -- something about this specific call/state is
different, not the general pattern.

Ruled out so far (read `backend/routes/teams.js`, `db/schema.sql`,
`db/migrations/`):
- `GET /teams/:id`'s SQL is unchanged in shape from what already worked
  during the 2026-09-20 fix; `stadiums.timezone` (selected but not
  modeled in `TeamDetail`) is a base-schema `NOT NULL` column, not a
  recent migration, so it can't be a missing-column 500.
- `TeamDetail`/`RosterPlayer` Decodable models match the route's actual
  JSON shape field-for-field; Swift's synthesized `Decodable` ignores
  extra keys, so no decode mismatch expected there.
- Route requires the same JWT (`authenticate` middleware) as every
  other working screen (Board/Games/Players) -- not a distinct auth
  path.
- Couldn't confirm live behavior directly: no way to hit the production
  API from this shell to check a real response for the team JD tested
  (outbound HTTPS from the device shell isn't reachable here), and this
  can't be reproduced without Xcode/a simulator.

Added temporary `#if DEBUG` print instrumentation (same pattern that
solved this the first time, per the "Resolved" section above) rather
than guessing further:
- `TeamDetailViewModel.load(teamId:)` now prints on start, on success
  (team name + roster count), on every catch branch, and on exit
  (final isLoading/team/error state).
- `TeamDetailView.body` now prints its own read of
  isLoading/team/errorMessage on every body evaluation, so we can see
  exactly which branch is (or isn't) active when the screen renders
  blank.

**Next step: JD to rebuild, reproduce (Research > Teams > any team)
with the Xcode console open, and share the `[TeamDetailView]` /
`[TeamDetailViewModel]` / `[APIClient]` lines that print** -- that will
show directly whether the request is failing, hanging, or something
else is going on, rather than guessing further from the source alone.
Both sets of prints are marked TEMP DEBUG and will be removed once this
is resolved, same as last time.

**Update:** JD reproduced and shared the console output. It showed the
`[TeamDetailView] body eval` line (isLoading=false/team=nil/error=nil --
the blank-render state) firing right after selecting Buffalo Bills
(team 65), but no `[TeamDetailViewModel] load(teamId: 65) starting`
line ever appeared, and no `[APIClient] GET /teams/65` call either. So
`body` genuinely ran, but `.task { await viewModel.load(...) }` never
actually invoked the closure -- confirmed, not just theorized. This
matches a known SwiftUI/NavigationStack quirk where `.task` can fail to
fire on a view pushed from a List row's `NavigationLink(value:)` in
some cases, even though the exact same pattern works elsewhere in this
app (Players/Games/GameDetail/PlayerDetail all also push from List rows
and their `.task` does fire) -- so it's not a universal bug, just
something about this one path triggering it.

**Fix attempt:** swapped `TeamDetailView`'s trigger from `.task { await
viewModel.load(teamId: teamId) }` to `.onAppear { Task { await
viewModel.load(teamId: teamId) } }` -- `.onAppear` is the more
primitive, longer-standing API and doesn't have `.task`'s occasional
List-push firing quirk. Kept a print in both the `.onAppear` closure
and inside `load(teamId:)` so the next console capture tells us clearly
whether this fixed it (onAppear print + load-starting print both show,
followed by the team loading) or whether even `onAppear` doesn't fire
(which would mean the view genuinely isn't appearing/completing its
push, a deeper navigation issue rather than a load-trigger issue).

**Next step: JD to rebuild, reproduce again with the console open, and
share the fresh output** -- specifically whether `[TeamDetailView]
onAppear` and `[TeamDetailViewModel] load(teamId: ...) starting` now
print, and whether the team actually loads on screen this time.

**Update 2:** Same result after `.onAppear` too -- byte-identical
console output, confirmed even after a clean build (Product > Clean
Build Folder). JD also confirmed: the back chevron works (can navigate
back), no crash/red error shown in Xcode, it happens on *every* team
(not just Buffalo Bills), and waiting on the blank screen indefinitely
never changes anything. That ruled out the trigger mechanism (`.task`
vs `.onAppear`) entirely -- something was preventing the pushed view
from ever becoming "live" in the first place, which pointed away from
`TeamDetailView` and toward the navigation push itself, i.e. the
*source* of the push: `TeamsListView`.

**Root cause found:** `TeamsListView` was the only one of the four
Research-tab list screens (Games/Teams/Players/+ this) built with
`List(viewModel.teamsByDivision) { section in Section { ForEach(...) {
NavigationLink(...) } } header: {...} }` -- the `List(data:rowContent:)`
shorthand where each top-level element's row content is itself a
`Section` wrapping a further nested dynamic `ForEach`/`NavigationLink`.
`GamesListView` (`List(viewModel.games) { game in NavigationLink(...) {
... } }`) and `PlayersListView` (`List { ForEach(viewModel.players) {
player in NavigationLink(...) { ... } } }`) both push fine and both use
a plain, single-level row shape instead. Nesting a dynamic
`Section`/`ForEach` inside `List`'s own per-element row closure is a
known SwiftUI rough edge that can silently break `NavigationLink(value:)`'s
destination resolution -- the destination gets constructed (hence the
one `body eval` print we kept seeing) but never actually mounted live,
consistently, for every element, exactly matching everything JD
reported.

**Fix:** rewrote `TeamsListView` to use an explicit
`List { ForEach(viewModel.teamsByDivision) { section in Section { ... }
header: {...} } }` instead -- same visual result (32 teams grouped by
division with section headers), same shape `TeamDetailView`'s own
roster-by-position list already uses. Reverted `TeamDetailView`'s
trigger back to plain `.task` (matching every other screen) now that
the real fix is upstream; kept both sets of debug prints for one more
round to get positive confirmation from the console before removing
them.

**Next step: JD to rebuild and reproduce once more.** Expect to now see
`[TeamDetailViewModel] load(teamId: ...) starting`, a successful
`[APIClient] GET /teams/<id> -> 200 ...`, and the team's roster actually
rendering on screen. Once confirmed, remove the TEMP DEBUG prints from
`TeamDetailView.swift` and `TeamDetailViewModel.swift`.

**Update 3 -- first fix was incomplete.** After rebuilding, opening the
Teams list alone no longer printed `[TeamDetailView] body eval` (good --
confirmed the `List(data:)` eager-pre-build theory was real and that
part is fixed), but actually tapping into a team was **still** fully
blank, byte-identical symptom (`body eval` once, nothing after). So the
`List(data:) { Section {...} }` -> `List { ForEach { Section {...} } }`
change fixed a real but secondary issue (the destination being
pre-built as soon as the list appeared), not the primary one (the
destination never becoming live once actually pushed).

Grepped the whole codebase for `Section {` next to `NavigationLink(value`
to find precedent: **`TeamsListView` and `TeamDetailView` were the only
two places in the app using `Section { ForEach { NavigationLink(value:) } }`**
-- a NavigationLink two nesting levels deep inside a List (outer ForEach
-> Section -> inner ForEach). Every other list-to-detail push in the
app (Games, Players -- both also two navigation hops deep from a tab
root, same depth as Research > Teams > team) uses a flat, single-level
`List { ForEach { NavigationLink } }` with no Section in between, and
those all push correctly. No confirmed-working precedent existed
anywhere in this codebase for a Section-nested NavigationLink(value:),
so rather than keep debugging SwiftUI's Section/NavigationStack
interaction blind, flattened both lists to the same flat shape that's
already proven to work:

- `TeamsListView`: division headers are now plain `Text` rows
  interspersed in one `ForEach` over a flattened `[TeamsListRow]`
  (`.header`/`.team` cases) instead of real `Section`s. `.listStyle`
  switched from `.insetGrouped` to `.plain` to match (no more native
  section chrome to speak of).
- `TeamDetailView`: same treatment for the roster-by-position list --
  flattened into `[RosterRow]` (`.header`/`.player`), one `ForEach`, no
  `Section`. Did this **preemptively** even though it hadn't been
  reached/tested yet (TeamDetailView never rendered far enough to try
  tapping into a roster player) -- it has the exact same nesting
  pattern, so it would very likely have hit the identical bug the
  moment someone tried Team > player.

This loses the native sticky section-header look (division/position
group headers are now plain rows that scroll with the list, not pinned)
-- a fair trade for navigation actually working; can revisit the visual
styling once this is confirmed fixed. Kept both sets of TEMP DEBUG
prints for one more round.

**Next step: JD to rebuild and reproduce once more (Research > Teams >
any team).** Expect `[TeamDetailViewModel] load(teamId: ...) starting`
to finally appear, followed by a successful `GET /teams/<id>` and the
team + roster actually rendering. If this STILL doesn't work, the
Section-nesting theory is wrong too and this needs a fundamentally
different diagnostic (e.g. an unconditional, always-rendered marker
Text outside the loading/loaded Group entirely, to prove definitively
whether TeamDetailView is mounting onto the screen at all) rather than
another structural guess.


## Resolved — Teams initial empty Group prevents loading (2026-09-24)

JD reported the flattened-list build still logged only
`[TeamDetailView] body eval — teamId=65 isLoading=false team=false error=nil`.
Investigated and reproduced before changing production Swift files.

**Cause:** `TeamDetailView` was the only affected detail screen whose
root was a `Group` with no child in the initial state. Loading is false,
error is nil, and team is nil, so neither branch exists. The `.task`,
background, and navigation-title modifiers have no rendered child to
attach to. The task never starts, so the view can never leave that
state. Switching `.task` to `.onAppear` on the same empty group cannot
solve it. Game/Player Detail already use permanent `ScrollView` roots;
TeamsListView's Group has an unconditional `else` containing a List.
A codebase search found no other screen with the same empty-root/load
cycle.

**Controlled evidence:** Xcode 26.5, iPhone 17 Pro simulator, iOS 26.5.
An isolated app compiled the repository's actual TeamDetailView,
TeamDetailViewModel, team/roster models, AsyncStateView, and brand
extensions. Only the API boundary and outer navigation shell were test
fixtures (no production requests, credentials, or backend changes).
- Unchanged source: navigated Research → Teams → team 65; exact body
  log, blank screenshot with back button but no title, zero requests.
- Temporary copy with ONLY root `Group` → `VStack(spacing: 0)` changed:
  load starts, exactly one initial request, header/title/empty-roster
  message appear. This isolates the root container as the cause.
- Nested `ForEach → Section → ForEach → NavigationLink(value:)` source
  list also works with the corrected destination, including a real
  simulator tap after navigating back. Section nesting was not the cause.
- Final repository source: observed loading and error states, tapped
  Try again, then observed populated roster and tapped its player link
  successfully (player destination was a harness marker, not the full
  PlayerDetail screen). Empty-roster success was verified separately
  with the one-line candidate. No duplicate request on the initial
  loading-to-content transition.

**Change:** TeamDetailView now uses a permanent VStack with a full-size,
top-leading frame so loading/error backgrounds fill the screen. Kept
`.task` as the lifecycle trigger. Removed temporary Teams body/load
prints; retained APIClient's generic DEBUG diagnostics. Corrected the
misleading comments in both Teams views. Existing flattened list styling
is retained, without another unrelated layout rewrite. No model,
endpoint, displayed-data, or backend behavior changes.

**Validation:** full Debug iOS Simulator app build succeeds using
`xcodebuild -project 'Chalk That NFL.xcodeproj' -scheme 'Chalk That NFL'
-configuration Debug -sdk iphonesimulator -destination
'generic/platform=iOS Simulator' -derivedDataPath
/tmp/chalk-team-investigation/build CODE_SIGNING_ALLOWED=NO build`.
All 84 Swift files pass `python3 scripts/check_balance.py`. The initial
full build reports the two pre-existing AuthViewModel Sendable/main-actor
warnings; these are outside this change. Build logs and isolated harness
are in `/tmp/chalk-team-investigation` for this session (temporary,
not repository dependencies). Installed and launched the rebuilt real app;
it shows Login, so authenticated live-team data was not verified. iOS 16
remains the deployment target; runtime checks used iOS 26.5, not iOS 16.

**JD confirmation (2026-09-24):** after trying the fix, JD replied,
"yup that worked. Thanks!" The reported Research → Teams → team blank
screen is now resolved; no further diagnostic round is pending. This
confirmation is separate from Codex's offline simulator checks above.
It does not claim that JD separately tested every roster, retry case,
or iOS version. The temporary Teams logging has already been removed,
and the generic APIClient DEBUG logging remains available for future
issues.

## Status

- [x] Xcode project scaffolded (`Chalk That NFL.xcodeproj`, min iOS 16,
      no third-party deps, `Models/ViewModels/Views/Network/Services/
      Extensions` layout, `PBXFileSystemSynchronizedRootGroup` — Xcode
      auto-discovers files added under `Chalk That NFL/`, no manual
      project-file editing needed for new files).
- [x] `Extensions/Color+Brand.swift` — all 15 Stadium Lights tokens.
- [x] `Extensions/Font+Brand.swift` — needs real font files, see above.
- [x] Network layer: `Endpoints`, `KeychainManager`, `TokenRefresher`,
      `APIClient` (refresh-and-retry-once, shared in-flight refresh).
- [x] Auth: `AuthViewModel`, `LoginView`, real `/login`/`/refresh`/
      `/logout` calls.
- [x] App entry (`Chalk_That_NFLApp.swift`) + `MainTabView` shell — all
      four tabs, and every screen under each of them, are real now, each
      with a working Log Out (top-right menu).
- [x] Games — list (season/week picker, seeded from current-week) +
      full detail (header, weather, Model vs. Market, Odds, Injuries,
      Player Stats, Live Box Score, Drive Feed) — full parity with
      GameDetailPage.jsx as of the 2026-09-21 phase.
- [x] Teams — list by division + detail with grouped roster. Initial
      empty-Group blank-screen bug fixed and confirmed by JD (2026-09-24).
- [x] Players — search/filter list + full detail (bio/injury, matchup/
      insight cards, and the Season Avg/Season Total/Last 5/Career/Game
      Log stat tabs with home-away/time-slot/weather filters) — full
      parity with PlayerDetailPage.jsx as of the 2026-09-22 phase.
- [x] Board — this week's games (grouped by date, with weather/odds/
      edge badges), Top Edges, Rankings Leaders (passing_yards preview).
- [x] Player Props + Odds — market tabs, per-game grouped cards,
      recent-form context, pregame lean + final-game grading.
- [x] Rankings + Edge — full Rankings tab (stat category/season/week
      filters, Signal badge, season-avg), full Edge tab (season/week/
      only-disagreements filters), and GameDetailView's "Model vs.
      Market" section. Per-game full Odds section now wired too — see
      the 2026-09-21 GameDetailView full-parity phase below.
- [x] Portfolio / Picks / Leaderboard — Portfolio (preview/build-&-log a
      slate, under Agents), Picks (portfolio_agent_v1's record + full
      pick list, under the new Record tab), Leaderboard (all agents
      ranked by hit rate, also under Record).
- [x] Chat — the research-assistant tab (POST /chat), with the same
      markdown-rendering scope (bold/lists/pipe tables) web's own hand-
      rolled renderer covers. This was the last phase in the original
      build order — every Agents/Record/Research/Board screen was real
      after this.
- [x] GameDetailView full parity (2026-09-21) — Odds (full per-
      bookmaker table), Player Stats (season avg/total, both rosters),
      Live Box Score (per-game stats + Top Performers), and Drive Feed
      all added, matching GameDetailPage.jsx's full section set and
      order.
- [x] App icon (2026-09-23) — JD supplied the final artwork (a
      photorealistic football + red uptick arrow + green bar chart on a
      dark navy background); cropped out of its "icon mockup" frame
      into a proper full-bleed 1024x1024 and wired into
      `Assets.xcassets/AppIcon.appiconset` (single-size modern app icon
      format — Xcode generates every other size from this one).

## Historical build-verification gap — superseded 2026-09-24

The full app now builds with Xcode 26.5; the following records the original
scaffolding limitation, not a current blocker.

This project was scaffolded from a Linux shell on your Mac (no Xcode/
swiftc available there), so the `.pbxproj` was hand-written to match
the MLB app's real, working project-file shape rather than verified by
an actual `xcodebuild`. Open it in Xcode as the first step and let me
know immediately if anything fails to open or build — much easier to
fix now than after more screens are layered on top.


## Board verification pass — bugs found and fixed (2026-09-20)

JD asked me to independently verify the Board screen against his actual
screenshots rather than assume it was correct. It wasn't — three real
bugs, all now fixed:

1. **"Date TBD" for every game, kickoff times missing from card
   subtitles.** Root cause: `Game.kickoffDate` parsed `game_datetime`
   with a default-options `ISO8601DateFormatter()`, which cannot parse
   fractional seconds. The backend always sends timestamps with
   milliseconds (`"2026-09-21T17:00:00.000Z"`, because Node's
   `Date.prototype.toJSON()` always includes them), so `kickoffDate`
   silently returned `nil` for every game, and `BoardViewModel`'s
   grouping fell back to its "Date TBD" bucket every time. This was
   very likely a pre-existing bug from the Games phase too (kickoff
   times were probably always blank there — just less visible than a
   giant "Date TBD" heading). Fixed by giving `Game.kickoffDate` a
   `.withInternetDateTime, .withFractionalSeconds` formatter first,
   falling back to the old default-options formatter for safety. Same
   root-cause fix applied to `OddsBadgeLogic.latestDK()`'s `syncedAt`
   comparison in `Badges.swift` (low practical impact there since the
   server already dedups odds rows via `DISTINCT ON`, but fixed for
   correctness).
2. **"Board" showing twice** — the nav bar's own large title plus a
   redundant in-content `Text("Board")` in `BoardView`'s `header`.
   Removed the duplicate, matching how `TeamDetailView`/`PlayerDetailView`
   don't repeat their nav titles in-body either.
3. **"SEASON 2,026 · WEEK 2" comma bug** — SwiftUI's
   `Text("...\(someInt)...")` string interpolation goes through
   `LocalizedStringKey`, which applies locale-aware grouping separators
   to raw `Int`s by default. `GamesListView.swift` already had the
   correct fix pattern in one spot (`String(season)`); the rest of the
   app didn't. Fixed every occurrence of this bug class I could find via
   grep, converting each to an explicit `String(...)` conversion before
   interpolation:
   - `BoardView.swift`: season/week line, "No games scheduled for week
     N yet." empty state, rankings-row rank number.
   - `BoardGameCardView.swift`: the score line (`away–home`).
   - Pre-existing occurrences from the Games phase, fixed for
     consistency now that the pattern is understood: `GameRowView.swift`
     (score line), `GameDetailView.swift` (team score), `GamesListView.swift`
     ("Week N" picker label).

Verified all 44 Swift files still have balanced braces/parens after
these edits (same shell-only check used after every change in this
project, since there's no Xcode/swiftc here). Not yet build-verified —
please rebuild and check: games group under real per-day date headings
with kickoff times showing, "Board" appears once, and the season/week
line and any scores/ranks display without stray commas.
