# FarmSync Hub — App Overview for Website Build

> This document describes the FarmSync Hub mobile app so it can be used as a brief for building a marketing/product website. Share this file with Claude along with the request "build me a website for this app."

---

## 1. What the app is

**Name:** FarmSync Hub
**Tagline (suggested):** *Every farm, one workspace.*
**Platform:** Mobile app (Flutter — Android/iOS), works offline-first with cloud sync.
**Description:** A Farm Management Information System (FMIS) built for smallholder farmers, initially focused on Jos South LGA, Plateau State, Nigeria. It brings farm records, crop and livestock tracking, finances, AI advice, and market/sales tools into a single mobile workspace designed for farmers who may have unreliable internet access.

**Mission:** Help subsistence, semi-commercial, and market-oriented farmers move from paper records and guesswork to organized, data-driven farm management — without needing constant connectivity or technical skill.

**Target users:**
- Smallholder and subsistence farmers
- Semi-commercial farmers
- Market-oriented / commercial farmers
- Farm cooperative admins who manage many farmer accounts

---

## 2. Core features

### 🌾 Farm Management
- Create and manage multiple farm profiles (name, location, size in hectares, soil type, water source)
- Farmer category classification: Subsistence, Semi-Commercial, Market-Oriented
- Farm detail pages with field records, documents, and environmental readings
- Farm insight summaries and AI-generated reports

### 🌱 Crop Tracking
- Log crops with variety, planting date, expected harvest date, area planted
- Growth-stage tracking: Seeding → Germination → Vegetative → Flowering → Fruiting
- Crop detail screens with history and recommendations
- Crop advisory catalog for guidance by crop type

### 🐄 Livestock Management
- Track species, breed, counts (male/female), purpose, and housing
- Health status monitoring: vaccinations, treatments, checkups
- Birth and death event logging
- Livestock detail and health-log history

### 💰 Finance & Sales
- Income/expense transaction tracking by category (crop sales, livestock sales, inputs, labour, veterinary, other)
- Dedicated finance workspace with balance, totals, and monthly summaries
- **Sales Desk** — record sales, generate and share sales receipts
- **Procurement** tracking for farm input purchases/orders
- **Market Trends** screen for pricing insight
- **AI Finance Recap** — AI-generated summary/analysis of farm finances
- PDF export and share of financial/insight reports

### 🤖 AI Advisor
- Chat-based AI assistant for crop advice, animal health, soil management, and market prices
- **Snap & Diagnose** — take or upload a photo (e.g., of a crop/leaf) for AI diagnosis
- Voice mode support
- Powered by Firebase AI (Gemini)

### 📚 Learn (Farmer Education)
- Structured lessons and learning tracks covering crops, livestock, soil, weather, and finance
- Practice activities with "understanding check" quizzes
- Video lessons (embedded YouTube content)
- Progress tracking and completion stats
- **Shareable certificates** awarded on course/lesson completion

### 📰 News & Notifications
- In-app news feed relevant to farmers
- Push notifications and email notifications (weather alerts, reminders, updates)
- Notification detail views and history

### 🌦️ Weather
- Weather forecast widget on the dashboard (temperature, humidity, rainfall)

### 👤 Accounts & Profile
- Email/password, phone number, and Google Sign-In authentication
- Email verification, password recovery, invite-based account creation
- Farmer profile: name, phone, ward/location, language
- Multi-language support: **English, Hausa, Berom**
- Light mode / Dark mode theming
- Verified badge system for trusted/established farmers

### 🔄 Offline-First Sync
- Full offline functionality with local on-device database
- Automatic sync status indicators: Synced / Pending / Offline
- Background sync to Firebase Cloud Firestore when connectivity returns
- Built for areas with unreliable or intermittent internet access

### 🛠️ Admin Console
A separate admin experience for platform operators/cooperative managers:
- Admin dashboard with platform metrics
- User management and user detail views
- Verified badge request approvals
- News post management
- Admin notes and internal notifications
- Multi-admin management with recovery/locked-account handling

---

## 3. What makes it different

- **Offline-first, not offline-tolerant** — built from the ground up for low-connectivity rural areas, not just a fallback mode.
- **All-in-one workspace** — farm, crop, livestock, finance, sales, and learning live in one app instead of scattered tools.
- **AI embedded throughout**, not bolted on — advisory chat, photo diagnosis, and auto-generated finance/farm insight reports.
- **Built for a real place** — designed around the practical needs of farmers in Jos South LGA, Plateau State, Nigeria, with local languages (Hausa, Berom) supported alongside English.
- **Farmer growth path** — categorization (subsistence → semi-commercial → market-oriented) reflects and supports a farmer's business growth over time.

---

## 4. Brand identity

**Visual style:** Warm, natural, "botanical" — leaf and field imagery, soft cream surfaces in light mode, deep green/near-black surfaces in dark mode.

**Color palette:**
| Role | Color | Hex |
|---|---|---|
| Primary brand green | Botanical green | `#32D583` |
| Secondary green | Active/FAB green | `#22C55E` |
| Teal accent | `#14B8A6` |
| Harvest amber (warnings/sunny weather) | `#FBBF24` |
| Sun gold (weather hero) | `#F8D58A` |
| Sky blue (illustrations) | `#B9E3FF` |
| Mint (chips/gradients) | `#CFEFBD` |
| Soil brown (input/soil data) | `#8B5E3C` |
| Light surface (cream) | `#FFFBF2` |
| Soft green surface | `#F2FAEE` |
| Dark background | `#070B11` |
| Dark card | `#111827` |

**Typography:**
- Display/headline font: **DM Serif Display**
- Body/UI font: **Plus Jakarta Sans** (weights: regular, medium, semibold, bold)

**Imagery themes:** leaf backgrounds, leaf fields, smart-farm tech, field sprayers, produce markets, farm landscapes.

---

## 5. Suggested website sections

1. **Hero** — tagline, short value prop, app store badges / "Coming soon" or download CTA
2. **Problem → Solution** — paper records & disconnected tools vs. one offline-first workspace
3. **Feature showcase** — Farms, Crops, Livestock, Finance & Sales, AI Advisor, Learn (use the feature list in §2, likely with phone-mockup screenshots)
4. **AI Advisor spotlight** — highlight Snap & Diagnose and chat advisor as a differentiator
5. **Offline-first callout** — explain why this matters for the target region
6. **Learn / education section** — lessons, certificates, farmer growth story
7. **Who it's for** — subsistence / semi-commercial / market-oriented farmer personas
8. **Local focus** — Jos South LGA, Plateau State, Nigeria; language support (English, Hausa, Berom)
9. **Testimonials / trust** (placeholder if none yet)
10. **Footer / contact / download links**

---

## 6. Notes for the website builder

- No public marketing copy or logo files exist yet beyond the in-app icon and UI photography (`assets/ui/*.jpeg`) — treat brand imagery as a starting point, not final assets.
- App is not yet described as publicly launched; confirm with the app owner whether to include app store links or a waitlist/CTA instead.
- Keep messaging grounded in the real feature set above — avoid inventing features (e.g., no marketplace/e-commerce checkout exists yet; "Sales Desk" is for the farmer's own record-keeping and receipts, not a public marketplace).
