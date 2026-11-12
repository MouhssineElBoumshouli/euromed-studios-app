# 0002: Brand system

Status: approved direction (Mouhssine liked v2, final call after seeing full screens)
Date: 2026-11-12

## Sources

- `sources/uemf-brand-book.pdf`: UEMF's official logo page from the Direction de la Communication.
- `sources/photos/`: the Euromed Studios brochure and photos of each studio.

## The idea

The app belongs to two brands:

- **UEMF**, the institution: blue and green. Its official colors give the app trust and make it feel official.
- **Euromed Studios**, the place: night navy, gold, bold condensed titles, and the textures of the studios.

So the **frame** of the app is Studios (navy and gold headers, condensed titles). **Actions** use UEMF blue. **"Validée"** uses UEMF green. A faint zellige star pattern, like the art in the podcast room, appears only in headers.

## Colors

| Token | Hex | Where it comes from | Use |
| --- | --- | --- | --- |
| `uemf-blue` | `#003882` | Brand book, Pantone 294 (R0 G56 B130) | Main buttons, links, selected states |
| `uemf-green` | `#0DB02B` | Brand book, Pantone 361 (R13 G176 B43) | Icons and fills for "approved". **Never for text** (contrast 2.9:1) |
| `green-text` | `#0B7A23` | A darker shade of UEMF green | Green text (5.5:1) |
| `studios-night` | `#0A1230` | The brochure | Headers, the dark brand surface, main text |
| `studios-blue` | `#1C2B6B` | The Plateau TV set | Studio cover backgrounds |
| `studios-gold` | `#B39467` | The Euromed Studios logo | Accents on the night background only (6.4:1). **Never as text on white** (2.9:1) |
| `gold-text` | `#8A6A3A` | A darker shade of the gold | Gold text on light backgrounds (5.0:1) |
| `stone` | `#F5F1EA` | The walls and wood | App background |
| `surface` | `#FFFFFF` | | Cards and sheets |
| `ink-muted` | `#5A5F73` | | Secondary text (5.6:1 on stone) |
| `warning-bg` / `warning-text` | `#F6EEDD` / `#6E5321` | | The "pending" chips (6.2:1) |
| `danger` | `#B42318` | | Refusals and errors (6.6:1) |

Contrast was measured against WCAG AA: 4.5:1 for normal text.

## Type

- The brand book says **Gotham**. Gotham is a paid font, so we use **Montserrat**, its closest free match, for all interface text. If UEMF gives us a Gotham license, we swap it in one place.
- **Barlow Condensed** (semibold, uppercase) for big titles only, matching the brochure's studio names.
- Arabic, if we add it later: IBM Plex Sans Arabic.

## Logos

The UEMF logo files couldn't be downloaded (the download link is broken). For now we use text placeholders, and we'll get the files from UEMF at the meeting. The brand book's rule applies: never change the logo's colors, proportions or orientation, and always keep clear space around it.
