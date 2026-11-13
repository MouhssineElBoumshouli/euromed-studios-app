# 0005 · Notifications come from the booking history

- **Status:** proposed by Claude and built for review (13 Nov 2026). Mouhssine to confirm.

## Decision

The in-app notification feed is **computed** from the bookings each person may already see, using each booking's append-only history (submitted, approved, refused, cancelled, checked in, closed, absence). The only thing the server stores is "read up to", one time per person (`profiles.notifications_seen_at`).

## Why

- **One source of truth.** The feed can never contradict the bookings.
- **Same privacy as the bookings.** Row-level security already limits what each person sees, so it also limits their feed.
- **Simple.** No extra writes, nothing to clean up. It works the same offline (tests) and live.

## Who gets what

| Event | Who is notified |
|---|---|
| A request waits for a decision | The approver who can decide, until it's handled (counts as unread) |
| Level 1 approved, validated, refused, cancelled by admin, closed, absence | The requester |
| Session validated with a technician assigned | That technician |
| A validated session is cancelled | Studio staff |
| 1 hour before a validated session | The requester and the technician |

Nobody is notified of their own actions.

## Limits and next steps

- Notifications appear inside the app only. **Phone push and email** will need a server-side outbox: same rules, but the server sends them. That's planned for the production phase. For email, UEMF must say which mail service to use.
- The 1-hour reminder lead is a placeholder (Q21).
