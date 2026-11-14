# 0006 · New logo and month calendar for booking

Status: approved by Mouhssine (2026-11-14), at the team's request.

## What
- The app uses the new Euromed Studios logo: a shield with a sound equaliser, "EUROMED" in white (navy on light backgrounds) and "STUDIOS" in gold.
  - It is drawn in code (`core/widgets/logo.dart`), so it stays sharp at any size.
  - It is also used for the web icons and the loading screen (`app/web/`).
- Booking now starts with a month calendar ("Choisissez une date"), like the team's earlier screen. Then come the slots, the details and the review (4 steps instead of 3).

## Calendar rules
- Days you can't book are grey: past days, closed days, and days beyond the booking window.
- Full days are grey with a red dot and can't be picked.
- Free days show a green dot. The chosen day is navy, and today has a blue outline.
- A suggested slot from a studio page skips the calendar and opens the slots directly.

## Not changed
- The staff "Planning" page (the day timeline) is the same.
- Booking rules are unchanged.
