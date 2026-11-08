---
sidebar_position: 1
title: Vision
---

# Vision

**Fitr exists to make self-coaching feel precise, personal and beautiful.**

Most training apps optimise for content volume or social engagement. Fitr optimises for the
small, repeatable loop that actually changes a body: *choose the right movement, do it at the
right time of day, record what happened, adjust the next week.*

## The problem

A motivated person who wants to train alone faces a fragmented stack:

- A catalogue app for exercise ideas.
- A notes app for the plan.
- A spreadsheet for progression.
- A timer for holds.
- A calendar for consistency.
- A dozen contradictory videos for form.

The cost is not just time. It is **decision fatigue**. The plan loses coherence, progression
becomes guesswork, and the first busy week breaks the system.

## The Fitr answer

One system with three tightly connected surfaces:

1. **A catalogue with anatomical metadata.** Every exercise is classified by topic, type,
   region, primary and auxiliary muscles, difficulty, equipment and coaching notes. The
   metadata is real data, not tags invented for search.
2. **A day that respects your energy.** Training is distributed across six time regions.
   Wake and pre-sleep are recovery-oriented; morning and afternoon carry the quality work;
   midday and evening bridge the gap. The plan is generated, not manually assembled.
3. **A progression engine with receipts.** Volume and intensity rise each week. When you
   complete all prescribed work at a sustainable effort, the next week adds load or reps.
   The tracker shows the resulting improvement, not just activity.

## Who it is for

**The primary user** is a self-directed intermediate trainee who:

- trains mostly alone, at home or in a commercial gym;
- wants a mix of strength, mobility, yoga and conditioning rather than one discipline;
- cares about form, muscle balance and long-term joint health;
- enjoys owning their data and is comfortable running a small server;
- values a calm, premium interface over gamified noise.

**Secondary users** are beginners who want a guided first rhythm, and advanced trainees who
want a curated library with exact muscle mapping and weekly auto-progression.

## Jobs to be done

| Job | Fitr response |
| --- | --- |
| “Tell me what to do right now.” | Today view, grouped by time region, with the next incomplete task surfaced. |
| “I want to train around my day.” | Six-region plan, adjustable training days and session length. |
| “Make sure I keep improving.” | Weekly multipliers, autoregulated load bumps, improvement deltas. |
| “Show me that I’m consistent.” | Adherence, streaks, calendar heatmap, active days. |
| “Help me understand this movement.” | Animated figure, instructions, cues, breathing, muscles, equipment. |
| “I don’t want to lose my data.” | Self-hosted SQLite, exportable JSON API, offline catalogue. |

## Product principles

1. **Quiet over loud.** No confetti, no streak guilt, no infinite feed. One clear next action.
2. **Motion with meaning.** Animation explains the shape of the movement; it is not decoration.
3. **Show the math.** Progression and improvement are explainable, with visible multipliers and deltas.
4. **Respect recovery.** Rest days are designed, not empty. Recovery is part of the program.
5. **Own your data.** A local server and SQLite are features, not implementation details.
6. **One system, not six apps.** Catalogue, plan and tracker share the same exercise identity.

## Non-goals for v0.1

- Social feeds, leaderboards or public profiles.
- Nutrition and calorie tracking.
- Live heart-rate integrations.
- AI-generated workout plans without human-auditable rules.
- Multi-tenant SaaS billing.

## Success metrics

For a personal deployment, success is behavioural and measurable:

- **Adherence:** ≥ 80% of scheduled tasks completed in a week.
- **Progression:** at least one load, rep or hold record improves every two weeks.
- **Balance:** no primary muscle group above 35% of weekly primary work.
- **Durability:** streaks recover after a missed day; the app is opened on rest days too.
- **Clarity:** the user can explain *why* next week is harder without opening a spreadsheet.

## Long-term direction

The roadmap moves from a deterministic coach to an adaptive one, without giving up
auditability: richer autoregulation, mesocycles with planned deloads, wearable-informed
readiness, Apple Health export, and eventually multi-user sync — while keeping the
single-user, self-hosted path first-class.
