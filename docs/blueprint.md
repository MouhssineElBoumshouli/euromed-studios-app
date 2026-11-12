# App blueprint

The full app: who uses it, every screen, and how screens connect. The Figma file follows this list, and so will the code. Screen IDs (like `D2`) are used everywhere: Figma frame names, GitHub issues, code.

Requirement links (`R-xx`, `P-xx`) point to `docs/requirements.md`. Lines marked ➕ go beyond the Cahier des Charges. They're what a complete, enterprise-grade app needs.

## 1. Who uses it, and what they see

One app. What you see depends on your roles (P-01). The bottom tab bar changes per role.

| Person | Bottom tabs |
| --- | --- |
| **Requester**: student, professor, communication team, club representative, external client | Accueil · Studios · Réservations · Projets · Profil |
| **Level 1 approver**: Dean, Director, Vie Étudiante, Director of Communication, Vice-Presidency | adds **Validations** (and Accueil shows a "to approve" count) |
| **Studio manager** (Level 2) | Accueil · Validations · Planning · Projets · Profil |
| **Régisseur / technical team** | Régie · Planning · Scanner · Maintenance · Profil |
| **Administrator** | Tableau de bord · Planning · Gestion · Validations · Profil |

Someone with several roles switches with a role switcher in the Profil tab ➕.

## 2. Screens

### A. Access
| ID | Screen | Notes |
| --- | --- | --- |
| A1 | Splash | Euromed Studios mark on navy |
| A2 | Welcome | One screen: what the app does, "Se connecter avec mon compte UEMF" |
| A3 | UEMF sign-in | Microsoft 365 single sign-on (one login for all UEMF tools) ➕ (Q14) |
| A4 | External client sign-in | Email + one-time code ➕ (R-07) |
| A5 | First-time setup | Confirm establishment and profile, allow notifications ➕ |
| A6 | Charter | Read and sign the règlement intérieur. Shown the first time, and again when the charter changes (R-13) |
| A7 | No access yet | For accounts waiting for a role ➕ |

### B. Home
| ID | Screen | Notes |
| --- | --- | --- |
| B1 | Requester home | Next session with QR shortcut, pending requests, weekly quota meter (R-14), live studio status, "Nouvelle réservation" |
| B2 | Notifications | Grouped by today, this week and earlier. Every item opens its screen (R-19) |
| B3 | Search | Studios, bookings, projects ➕ |

### C. Studios
| ID | Screen | Notes |
| --- | --- | --- |
| C1 | Studios | Grouped by zone: Production, Pédagogie numérique, Postproduction (R-01). Filter by capability ➕ |
| C2 | Studio detail | Photos, room ("Area 2, shared with Euromed Radio"), capabilities from the technical matrix, included equipment, rules, next free slots, "Réserver" |
| C3 | Availability | Week view: free, pending ("En attente", R-15), booked, maintenance |
| C4 | Equipment kit detail | What's in the kit, how many are available (R-12) |

### D. Booking: 3 screens to send (R-33)
| ID | Screen | Notes |
| --- | --- | --- |
| D1 | Choose time | Date, then one or more slots (R-10). Shared-room warning. Quota left this week. Taken slots are crossed out |
| D2 | Details | Activity: Enregistrement / Captation / Montage / Mixage (R-11). Link to a project. Book for a club. Equipment kits marked required or optional (P-04). Note to the approver |
| D3 | Review and send | Summary, who will approve (R-17), charter check (R-13), "Envoyer la demande" |
| D4 | Sent | Status timeline: En attente entité → En attente studio → Validée (R-20) |
| D5 | Over quota | Explains the limit and when it resets (R-14) |
| D6 | Slot just taken | Someone else got it first. Suggests the next free slots (R-15) |
| D7 | Checking… | The network dropped mid-send. Never shows a false success (P-12) |

### E. My bookings
| ID | Screen | Notes |
| --- | --- | --- |
| E1 | Bookings list | Tabs: À venir · En attente · Passées · Refusées |
| E2 | Booking detail | Timeline with approver names and times, refusal reason (R-19), equipment outcome (P-05), cancel, add to calendar ➕ |
| E3 | QR pass | Full screen, max brightness, countdown, works offline. Only active during the slot (R-28, P-10) |
| E4 | Cancel | Confirm, with an optional reason |
| E5 | End-of-session report | Everything OK, or report an item with a photo and a severity (R-29, P-09) |

### F. Projects
| ID | Screen | Notes |
| --- | --- | --- |
| F1 | Projects list | Mine and shared with me, by stage |
| F2 | New project | Type (R-21, P-06), title, description, collaborators |
| F3 | Project board | 4 stages: Pré-production · Production · Post-production · Validation & archive (R-26) |
| F4 | Pre-production files | Upload a script, rundown or storyboard. Required before production starts (R-22) |
| F5 | Production | Linked bookings (R-23), "Réserver pour ce projet" |
| F6 | Post-production | Status (P-07), correction requests as a thread (R-24) |
| F7 | Quality check and delivery | The tech team's verdict. Secure download link (R-25, P-08) |
| F8 | Members | Invite, accept or decline, remove (R-27) |

### G. Validations (Level 1 and Level 2)
| ID | Screen | Notes |
| --- | --- | --- |
| G1 | Inbox | Requests in my scope, oldest first, with waiting time ➕ |
| G2 | Request detail | Who, what, when, project, the requester's history, conflicts. Approvers can't see their own requests here (P-02) |
| G3 | Approve | Level 2 also confirms the equipment, allows explicit substitutions (P-04), and can assign a technician (R-18) |
| G4 | Refuse | The reason is required. Ready-made reasons speed this up (R-19) |
| G5 | Done | Back to the inbox, next request |
| G6 | Delegate | Hand over approvals while away ➕ |

### H. Régie and technical team
| ID | Screen | Notes |
| --- | --- | --- |
| H1 | Live board | Every room: Libre / Occupé / Inconnu, last updated, who's in it (R-30) |
| H2 | Today | Timeline of every session today |
| H3 | Scanner | Scan a QR code |
| H4 | Scan result | Valid (name, studio, until when) or refused, with the reason (R-28) |
| H5 | Maintenance | Incidents by severity (P-09) |
| H6 | Incident detail | Photos, history, "Rendre indisponible", "Résolu" |
| H7 | Equipment out / in | Hand equipment out and take it back, for each booking ➕ |

### I. Administration
| ID | Screen | Notes |
| --- | --- | --- |
| I1 | Dashboard | Occupancy this week, pending requests, open incidents, average approval time ➕ |
| I2 | Global planning | All rooms on one timeline (R-09) |
| I3 | Users and roles | Assign roles and approval scopes, club representatives (P-01, P-03) |
| I4 | Rooms and studios | Rooms that share space, bookable or not, opening hours (Q1–Q3) |
| I5 | Equipment catalog | Kits, quantities, availability |
| I6 | Rules | Quotas per profile, slot length, booking window, QR grace period, approval chain per requester type (decision 0001) |
| I7 | Charter versions | Publish a new version. Everyone signs it again |
| I8 | Activity log | Who did what, and when (P-11) |
| I9 | External clients | Quotes and their status (R-07) |

### J. Profile
| ID | Screen | Notes |
| --- | --- | --- |
| J1 | Profile | Name, establishment, roles, quota, role switcher |
| J2 | Settings | Language (FR now, EN/AR later), notifications, dark mode, text size ➕ |
| J3 | Help and rules | Studio rules, how booking works, contact |
| J4 | Privacy | What data we keep and why (Moroccan Law 09-08) ➕ |

### K. States that every screen supports
Loading (skeleton shapes, not spinners) · empty · error with retry · offline banner · "Vérification…" (P-12) · no permission · forced update.

## 3. Main flows (these get prototyped first)

1. **Book a studio:** B1 → C1 → C2 → D1 → D2 → D3 → D4 → E2
2. **Level 1 approves:** notification → G1 → G2 → G3 → G5
3. **Level 2 approves:** G1 → G2 → G3 (equipment and technician) → G5. The requester gets "Validée" and a QR code
4. **Use the session:** B1 → E3 (QR) → H3/H4 (scan) → E5 (end report)
5. **Refusal:** G2 → G4 → the requester sees the reason in E2
6. **Project:** F2 → F4 → F5 (book) → F6 → F7

## 4. Design waves

| Wave | Screens | Why first |
| --- | --- | --- |
| 1 | A2–A3, A6, B1, C1–C3, D1–D7, E1–E3, G1–G5 | The core: book, approve, enter |
| 2 | F1–F8, H1–H7, E4–E5, B2 | Projects and day-to-day studio work |
| 3 | I1–I9, J1–J4, A4–A7, B3, G6, all K states | Admin, settings, edge cases |
