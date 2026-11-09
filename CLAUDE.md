# Backpack — context for Claude

A Flutter gear-weight tracker for hikers: the gear closet with weights, trips
built from it, a packing checklist. Goals: publish on Google Play, and a
portfolio project. The server is a separate repo at `C:\learning\backpack-server`
(its `CLAUDE.md` holds the API contract).

## Working with her

- She's a designer learning development (React background). Talk in Russian,
  in plain words, with analogies; explain what, why and the typical pitfalls.
- Big work: a written plan in stages first, then one stage at a time — stop
  for her review, preview the next stage, ask before continuing.
- She tests the UI herself on the emulator/phone: give her a short checklist
  of what to tap and what she should see. Don't drive the UI with adb.
- She creates accounts, repos and paid services herself; Claude guides step by
  step and does the mechanical follow-up.

## Rules

- **Commits only when she asks.** Authored as her (git identity "munory"),
  **no Co-Authored-By line**, short English message. **Never commit `.claude/`
  or `.env`.**
- **The database only grows.** Real installs exist: every schema change is a
  new `schemaVersion` with an additive `if (from < N)` step in `onUpgrade` —
  never wipe or re-seed. Current schema: **22**. After editing tables run
  `dart run build_runner build`.
- **Every UI string goes through l10n** — `lib/l10n/app_ru.arb` and
  `app_en.arb`, both. After editing ARB files run `flutter pub get` (not a
  standalone `gen-l10n`).
- **Accounts and sync are switched off** (2026-11-07): the app ships local-only.
  `--dart-define=ACCOUNTS=true` turns them on (`accountsEnabledProvider`);
  tests override it to true. Keep that code working and tested.
- **Screens never touch tokens or HTTP** — only `accountProvider` /
  `ApiClient`. Sync runs by itself (`syncProvider`); screens don't call it.
- **Sync bookkeeping lives in SQLite triggers** (`_createSyncSchema`): don't
  bump `updatedAt`, queue rows or log deletions by hand. Any write that sets
  `updated_at` explicitly is treated as coming from the cloud.
- Personal data stays minimal: email and an optional name. Nothing else about
  people (152-FZ, Play data-safety form).

## Code map (`lib/`)

- `data/` — the Drift database (`database.dart`; `.g.dart` is generated) and
  Riverpod providers. Weights are integer grams; enums stored as ints.
- `account/` — `ApiClient` (HTTP, token renewal done once for everyone),
  secure token storage, `accountProvider` (signed in / out).
- `sync/` — `SyncEngine` (one exchange with POST /sync; first sign-in merges
  by name), `SyncController` (when to sync, status for Profile), `wire.dart`
  (row ↔ JSON, matches the server's `src/sync/wire.ts`).
- `features/` — screens: dashboard, gear_list, add_item, trips, packing,
  profile, account (sign-in, sign-up with email code, reset, delete),
  data_transfer (CSV/XLSX import, export).
- `common/` — shared widgets, theme, formatting, l10n helper.

Key ideas:
- The phone is the source of truth and the app works fully offline; an
  account is optional.
- When two devices edit the same row, the later edit wins.
- The first sign-in merges same-named rows instead of doubling them.
- Deletions travel as tombstones.

## Commands

- Check before finishing: `flutter analyze` (must be clean) and `flutter test`.
- The emulator reaches the dev server as `http://10.0.2.2:3000` (the default
  `API_URL`). Building, installing and phone testing: the `device-testing`
  skill.
- Dev server: `npm run dev` in `backpack-server`; Postgres and Mailpit run in
  Docker. Mailpit (http://localhost:8025) catches every email locally.
- Tests talk to `test/helpers/fake_server.dart` (+ `fake_sync_server.dart`,
  which mirrors the server's sync rules); `test/helpers/phone.dart` simulates
  devices.

## Style

- UI: `STYLE_GUIDE.md`. Form errors: a field's own error under the field, a
  general one in a banner with an icon above the button.
- Code comments are short and say *why*. A test for every new behaviour.

## History

- `DECISIONS.md` — why things are the way they are, newest on top. Add an
  entry for each decision made with her.
- `PROJECT_STORY.md` — the narrative of the project.

## Stages

Done:
- the local app: gear, categories, trips, packing, import/export, RU/EN, units;
- the server: accounts, password reset, sync API, rate limits;
- app sign-in, with an email code at sign-up;
- app sync (stage 13).

Now: polishing the app itself (local-only v1), then publishing on Google
Play (release signing, store listing, a simple privacy policy).

Deferred until needed (e.g. job hunting), plan ready:
- **14** — VPS (REG.RU, Moscow, around 1000 ₽ a month) and a domain, server
  hardening;
- **15** — deploy with Docker + Caddy, backups at another provider, a real
  email service, `TRUST_PROXY`, a release build with `ACCOUNTS=true` and the
  production `API_URL`;
- **16** — then: notice to Roskomnadzor, a privacy policy covering accounts.
