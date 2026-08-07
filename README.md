# FarmSync Hub

A Farm Management Information System (FMIS) for smallholder farmers in Jos South LGA, Plateau State, Nigeria — built by [LBtech](https://lbtech.site).

FarmSync Hub helps small-scale farmers track crops, livestock, farm finances, and procurement in one place, with an AI advisor and localized learning content built for the realities of smallholder farming in Nigeria.

## Features

- **Farm & Crop Management** — track individual farms and crop cycles
- **Livestock Records** — manage livestock alongside crop operations
- **Finance Tracking** — income, expenses, and sales in one view
- **Procurement** — manage input purchases and suppliers
- **AI Advisor** — AI-assisted farming guidance (Firebase AI)
- **Sales & Reporting** — sales records with PDF export
- **News & Learn** — agricultural news and localized learning content
- **Admin Dashboard** — oversight and management tools
- **Offline-first Onboarding** — built for low-connectivity smallholder contexts

## Tech Stack

- **Flutter** (Dart) — cross-platform mobile app
- **Riverpod** — state management
- **Firebase** — Auth, Firestore, App Check, Firebase AI
- **Clean Architecture** — `domain` / `data` / `presentation` layer separation

## Project Structure

```
lib/
├── core/            # constants, theme, extensions, shared services
├── domain/          # models and business logic
├── data/             # repositories, local/remote data sources, services
├── presentation/     # screens and shared UI
└── providers/        # Riverpod providers
```

## Background

FarmSync Hub grew out of a research and needs-assessment process with smallholder farmers in Jos South LGA, including stakeholder surveys and an FMIS usability study distinguishing between farmer typologies. It's an active project, with grant applications submitted (FCI4Africa) and continued feature development.

## About LBtech

FarmSync Hub is built and maintained by [LBtech](https://lbtech.site), a technical services studio based in Jos, Plateau State, Nigeria.
