# 0001: Build now with adjustable defaults

Status: proposed, waiting for Mouhssine's OK
Date: 2026-11-12

## The situation

We will meet UEMF later, but there's no date yet. We don't want to contact Brahim Seddouki every day until then. We still want to make real progress now.

## The decision

We build now. Every UEMF policy question (Q1–Q17) gets the default answer proposed in `docs/questions-for-uemf.md`. Each default is built as a **setting an admin can change**, never hard-coded. That covers quotas, opening hours, slot length, who approves, which rooms share space, grace periods, languages and so on.

The questions file becomes the **agenda for the meeting**. We don't send it before then.

## Why

- Work doesn't stop while we wait.
- When UEMF answers, we change a setting instead of rewriting code.
- Big universities need this flexibility anyway, because rules change every year.

## The risk

A default could be very far from what UEMF wants. For example, a single approver could turn out to be a group of people. To limit this, the parts most likely to change are built generically: the approval chain is a list of steps, not exactly 2 fixed people, and rooms and studios are data, not code.
