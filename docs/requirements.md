# Requirements

Every requirement below comes from the Cahier des Charges (CdC). The "From" column gives the section. The full text is in `sources/cahier-des-charges-transcript.md`.

- **R-** items are what UEMF asked for. We build all of them.
- **P-** items are proposals. Most come from the old project's work. They only become rules once Mouhssine approves each one.
- Anything only UEMF can decide has a **Q-** number, matching `docs/questions-for-uemf.md`. Until the meeting, we use the proposed default answer, built as a setting an admin can change (see `docs/decisions/0001-build-with-adjustable-defaults.md`).

## Spaces

| ID | Requirement | From |
| --- | --- | --- |
| R-01 | The app shows the real layout of the center. **Production:** Plateau TV, Studio Podcast, Euromed Radio, Chroma Key Studio. **Digital teaching:** Studio Pédagogique, Speed MOOC. **Post-production:** video/audio editing stations and central control rooms. | §2 |

Note: the brochure and floor plan list more spaces than the CdC, such as Salon VIP, Studio Photo, Régie TV, Régie Podcast and Espace Montage. They also show that some studios share one room. → Q1, Q2

## Roles and access

| ID | Requirement | From |
| --- | --- | --- |
| R-02 | Access is based on roles. Each profile has its own rights and its own paths through the app. | §3 |
| R-03 | **Student:** limited access by default. Can see the spaces and what they offer. Limited access to projects (for example Studio Podcast or academic projects). Every request goes through approval. | §3 |
| R-04 | **Professor / Teacher-Researcher:** priority on Studio Pédagogique and Speed MOOC. Personal follow-up of their approved online-course projects. → Q8 | §3 |
| R-05 | **Communication team:** simple management of communication projects (Studio Podcast, Plateau TV). | §3 |
| R-06 | **Student clubs:** a shared group profile. Can book for approved cultural activities. Legal responsibility sits with the Direction des Affaires Estudiantines. → Q6 | §3 |
| R-07 | **External clients:** a commercial profile that needs specific authorization, with price or quote follow-up. → Q9 | §3 |
| R-08 | **Technical team:** manages equipment maintenance and receives the schedule. | §3 |
| R-09 | **Administrators:** see the whole schedule, manage equipment maintenance, give final approval on time slots, and supervise all projects. → Q5 | §3 |

## Booking

| ID | Requirement | From |
| --- | --- | --- |
| R-10 | A live schedule shows how the spaces are being used. Bookings can cover several time slots ("multi-créneaux"). → Q3 | §4.1 |
| R-11 | The user must choose the activity: Enregistrement (recording), Captation d'image (filming), Montage (editing) or Mixage audio (audio mixing). | §4.1 |
| R-12 | The user can add mobile equipment kits (cameras, microphones, lighting) to the room booking. | §4.1 |
| R-13 | Before sending any request, the user must sign the house rules (règlement intérieur) digitally. → Q11 | §4.1 |
| R-14 | Weekly hour limits per profile are applied automatically. The CdC only gives an example: 2 hours per week for students. → Q4 | §4.1 |
| R-15 | As soon as a request is sent, its slot shows as **"En attente"** on the shared schedule, so no one can double-book it. | §4.1 |

## Approval

| ID | Requirement | From |
| --- | --- | --- |
| R-16 | Every booking request goes through two approval levels, one after the other. | §4.3 |
| R-17 | **Level 1 (does this make sense?).** Students and clubs → their school or the Responsable de la Vie Étudiante. Professors and researchers → their Dean or school Director. Communication team → Director of Communication. External clients → Executive Vice-Presidency. → Q5, Q7 | §4.3 |
| R-18 | **Level 2 (can we technically do it?).** The studio management checks that the central control room is free, that technicians and sound engineers are available, and that no maintenance conflicts with the booking. | §4.3 |
| R-19 | A refusal at either level needs a written reason. The user is notified right away. | §4.3 |
| R-20 | The user sees their request's status live: *En attente entité* → *En attente studio* → *Validée*. | §4.3 |

## Projects

| ID | Requirement | From |
| --- | --- | --- |
| R-21 | Each project has a type: Enseignement/MOOC (teaching), Recherche (research), Culture, or Communication institutionnelle. | §4.2 |
| R-22 | **Pre-production:** the user must upload preparation files (script, show rundown or storyboard). | §4.2 |
| R-23 | **Production:** the project is linked automatically to its approved bookings. | §4.2 |
| R-24 | **Post-production:** track editing status. Users can ask for corrections or changes. | §4.2 |
| R-25 | **Approval and archive:** the technical team does a quality check, then the final file is delivered securely through a cloud link or a similar digital space. → Q12 | §4.2 |
| R-26 | Projects are shown as milestones or a Kanban board (columns you move cards across). | §4.2 |
| R-27 | The project owner can invite collaborators, for example a student monitor or a technician. | §4.2 |

## Extra features

| ID | Requirement | From |
| --- | --- | --- |
| R-28 | Once Level 2 approves a booking, the app creates a secure, temporary QR code. It works only during the booked slot. → Q10 | §4.4 |
| R-29 | An end-of-session form lets users report broken equipment or furniture right away. | §4.4 |
| R-30 | A régisseur dashboard (the person who runs the studios day to day) shows live which studios are in use. | §4.4 |

## Quality

| ID | Requirement | From |
| --- | --- | --- |
| R-31 | Schedule requests answer in under 200 ms. Calendar statuses show instantly. | §6 |
| R-32 | High availability, so QR door access is never blocked. → Q10 | §6 |
| R-33 | An intuitive interface that follows the Euromed Studios brand. Sending a project or a booking takes under 3 clicks. → Q13 | §6 |

## Tensions inside the CdC

These are points where two requirements pull against each other. We need a decision on each one, not a guess.

1. **R-33 vs R-11, R-12, R-13.** A booking needs a studio, a date and time, an activity, the house-rules signature and maybe equipment. That doesn't fit in 3 literal clicks. Our proposal: count *screens*, not taps, and remember the user's last choices. → Q13
2. **R-06 vs accountability.** A "shared group profile" usually means one shared password. That makes it impossible to know who did what. Our proposal: the club is a group, and each member who acts for it uses their own account. → Q6
3. **R-04 vs R-15.** If a professor has priority, can they take a slot that a student already holds "En attente"? → Q8
4. **R-09 vs R-18.** Does the Administrator give the final approval, or does the studio management? Are they the same person? → Q5
5. **R-01 vs the floor plan.** Several studios are the same room. Booking Plateau TV probably blocks Euromed Radio. → Q1

## Proposals from the old project

**Approved by Mouhssine on 2026-11-12.** All 13 are now rules.

| ID | Proposal |
| --- | --- |
| P-01 | One person can have several roles. Each action is still checked against the role it needs. |
| P-02 | Nobody can approve their own request. |
| P-03 | Club members act with their own accounts. No shared passwords. |
| P-04 | Equipment requests list each item, how many, and whether it's required or optional. Nothing gets swapped for something else without saying so. |
| P-05 | If an optional item isn't available, the room booking still goes through. The user is told clearly. |
| P-06 | Each project has exactly one type. |
| P-07 | Post-production status is one of: Not started, In progress, Correction requested, Ready for check. |
| P-08 | A failed quality check sends the project back to corrections. A passed check archives it and releases the final file. |
| P-09 | Incidents are Low, Medium or High. A High incident makes the item or room unavailable until someone fixes it. |
| P-10 | The QR code works from the exact start of the slot to its exact end, with no grace period unless UEMF says so. |
| P-11 | Every important action by an approver or admin is logged: who did it and when. |
| P-12 | Notifications only go out for things that really happened. If the network drops, the app shows "Checking…" instead of a false success. |
| P-13 | The interface is in French first. |
