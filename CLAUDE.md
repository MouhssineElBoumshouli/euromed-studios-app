# How we work

This file is for Claude (in chat) and Claude Code (the coding agent). Both follow it.

## Who decides

- **Mouhssine decides.** He owns the product, the design, the tech choices and the scope. AI can suggest, research, draft, build and review, but a suggestion is not a decision until Mouhssine says yes.
- **UEMF decides policy.** That means quotas, who approves what, prices and opening hours. If the Cahier des Charges doesn't say it, add it to `docs/questions-for-uemf.md`. Never guess it in code or design.

## What to trust, in order

1. `sources/`: the original Cahier des Charges and photos from UEMF.
2. Written answers from UEMF, saved in `docs/questions-for-uemf.md`.
3. Decisions Mouhssine approved, written in `docs/decisions/`.
4. Everything else, including the old `UEMF-Studio` repo and old chats. Treat these as ideas, not facts.

## Never

- Never edit anything in `sources/`.
- Never touch the old `UEMF-Studio` repo or its Figma file.
- Never push straight to `main` after the first setup. Every change goes through a pull request (PR).
- Never mark work done without running the checks.
- Never add sample data that looks real: no real names, phone numbers or student IDs.

## The loop: build, review, fix

1. Each piece of work is one GitHub issue.
2. One person or agent builds it on its own branch. Name the branch like `feat/12-booking-screen`.
3. The pull request stays small enough for one person to understand it in about 15 minutes.
4. **A different reviewer checks it.** If Claude Code built it, Claude reviews it, and the other way around. The reviewer answers one question in writing: *"What would break if this is wrong?"*
5. Mouhssine reads a short summary and approves the merge.

## Every pull request says, in plain words

- What changed and why.
- What did *not* change.
- How it was checked: tests, screenshots, or clicking through it.
- Anything Mouhssine should try himself.
- Any open question that should go to UEMF.

## Writing style

- Plain English. Short sentences. Explain any technical word the first time you use it.
- Anything that goes to UEMF is in French.
- The app's interface is in French first.

## Saving money and time

- Read only the files the task needs.
- Don't rewrite whole documents to change one part.
- Don't write long reports when a short list will do.
