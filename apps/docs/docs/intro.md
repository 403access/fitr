---
slug: /
sidebar_position: 1
title: Fitr documentation
---

<div className="hero-panel">
  <div className="hero-eyebrow">Self-coached fitness · v0.1.0</div>
  <h1 className="hero-title">Train on<br />your rhythm.</h1>
  <p className="hero-subtitle">
    Fitr is a personal fitness operating system: a beautifully animated movement catalogue,
    a day plan that flows from wake to sleep, and progress tracking that proves you are
    getting better — week after week.
  </p>
  <div className="badge-row">
    <span className="fitr-badge fitr-badge--lime"><span className="status-dot"></span> MVP shipped</span>
    <span className="fitr-badge">SwiftUI · iOS 18+</span>
    <span className="fitr-badge">Bun · TypeScript</span>
    <span className="fitr-badge">SQLite</span>
    <span className="fitr-badge fitr-badge--violet">60 exercises · 41 animations</span>
  </div>
  <a className="button button--primary" href="product/vision">Explore the product</a>{' '}
  <a className="button button--secondary" href="technology/architecture">Read the architecture</a>
</div>

Fitr is built for one specific person first: **you**. It is not a marketplace, a social feed,
or a generic 12-week PDF. It is a self-hosted training system that adapts every week, keeps
the whole movement library in your pocket, and shows its work through data.

## The three pillars

<div className="card-grid">
  <div className="feature-card">
    <div className="feature-icon">◎</div>
    <h3>Know the movement</h3>
    <p>
      Every exercise carries its topic, type, body regions, primary and auxiliary muscles,
      coaching cues, breathing and an original vector animation. Filter by any dimension.
    </p>
  </div>
  <div className="feature-card">
    <div className="feature-icon">☼</div>
    <h3>Follow the day</h3>
    <p>
      Six time regions — after wake, morning, midday, afternoon, evening, before sleep —
      each with a precise job. Rest days remain recovery days, not blank days.
    </p>
  </div>
  <div className="feature-card">
    <div className="feature-icon">↗</div>
    <h3>Prove the progress</h3>
    <p>
      Day, week, month and year views; calendar heatmap; adherence, minutes, volume, muscle
      balance, streaks, personal records and period-over-period improvement.
    </p>
  </div>
</div>

## How the system fits together

```text
┌────────────────────────┐        HTTPS / JSON        ┌──────────────────────────┐
│  SwiftUI app           │  ───────────────────────▶  │  Bun + TypeScript API    │
│  • daily rhythm        │                            │  • Hono router           │
│  • catalogue (offline) │  ◀───────────────────────  │  • plan generator        │
│  • Canvas animations   │        bootstrap           │  • progress engine       │
│  • progress charts     │                            └────────────┬─────────────┘
└────────────────────────┘                                         │
                                                                   ▼
                                                        ┌──────────────────────┐
                                                        │  SQLite (WAL)        │
                                                        │  catalogue · plans   │
                                                        │  tasks · history     │
                                                        └──────────────────────┘
```

The iOS app bundles a generated snapshot of the catalogue, so browsing and animations work
before the first successful network call. Plans, completions and analytics are authoritative
on the server.

## Start here

| If you want to… | Read |
| --- | --- |
| Understand the product and who it serves | [Vision](product/vision) |
| See every implemented capability | [Features](product/features) |
| Understand why each week gets harder | [Progression model](product/progression) |
| Learn the visual and motion language | [Design & motion](product/design) |
| Inspect the system design | [Architecture](technology/architecture) |
| Call the API | [API reference](technology/api) |
| Run it locally | [Development](technology/development) |
| Publish docs and website | [Deployment](technology/deployment) |
| See what comes next and what shipped | [Roadmap](roadmap) |

## Status

| Area | State |
| --- | --- |
| Exercise catalogue | ✅ 60 exercises, 6 topics, 8 types, 15 regions, 29 muscles |
| Daily plan by time region | ✅ Six regions, five-day week, recovery days |
| Progressive overload | ✅ Weekly volume/load targets + autoregulation from effort |
| Tracking | ✅ Day, week, month and year; calendar, heatmap, PRs, improvement |
| Exercise visualization | ✅ 41 hand-keyframed Canvas animations, no video assets |
| Bun API + SQLite | ✅ Typed REST API, deterministic plans, seeded demo history |
| Documentation | ✅ Docusaurus (this site) |
| Marketing website | ✅ Static site deployed alongside docs |
| GitHub deployment | ✅ Single Pages workflow for both sites |
| Multi-user auth | ⏳ Planned — header-based single-user mode today |

:::note[Demo data]
On first run the server seeds three completed weeks plus the current week up to yesterday,
so charts, streaks and personal records have a realistic baseline. Run
`bun run db:reset` to return to a clean install.
:::
