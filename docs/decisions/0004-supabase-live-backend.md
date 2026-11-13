# 0004 · Shared live data with Supabase

- **Status:** approved by Mouhssine (13 Nov 2026), after comparing alternatives
- **Context:** Badr and Mouhssine want a live demo. A student books on a phone, the studio team approves on a laptop, and each screen updates by itself.

## Decision

- **Supabase** (hosted Postgres, sign-in and live updates) holds the shared data. Project `euromed-studios-demo`, region Paris (eu-west-3).
- **The app only reads.** Every change goes through server functions that check the rules again: free slot (shared rooms included), opening hours, quota, signed charter, the two approval levels, no self-approval, the Q18 fallback, and a mandatory refusal reason. Row-level security decides who can read what. A modified app can't bypass any of it.
- **Live updates:** one tiny `world_version` row changes on every write. Apps listen to it and reload what they may see. Nobody receives other people's details.
- **Demo accounts:** the 12 fictional people, signed in with one tap. In the official version this becomes UEMF sign-in.

## Alternatives considered

- **Firebase:** a poor fit for overlapping time-slot rules, and hard to leave later.
- **PocketBase:** too young for an official university app.
- **A custom server:** most control, but weeks more work.

## Exit plan

Underneath it's plain Postgres, and Supabase is open source, so UEMF IT can host it themselves later. All server code is in `supabase/migrations/`. All app code that talks to the server is in `app/lib/data/live_sync.dart` and `booking_service.dart`.

## Known limits (demo)

- On the free plan, the project pauses after about a week without use. Press "Restore" in Supabase before a demo.
- Demo accounts share one password, and it's built into the app. The data is fictional, and the administrator can reset it.
