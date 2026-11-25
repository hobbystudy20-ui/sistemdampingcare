# Project memory

## Product intent & audience

- Internal/business web app with multiple pages: dashboard, booking, laporan (reports), and others.
- Primary language for UI and user communication: **Indonesian**.
- Goal: production-ready, fully featured app (not a demo/prototype).

## Brand personality & voice

- Assistant communicates in Indonesian; UI text is Indonesian.
- Tone: helpful, concise, conversational.

## Visual design & UX direction

- Stack: Vite + React (JSX), Tailwind CSS, Lucide React icons, `@/` path alias to `src/`.
- Global font sizing recently increased ~12.5% for readability across all pages and mobile views.
- Base text sizes are tuned for readability; further scaling is expected to be iterative on request.

## Decisions, constraints & rationale

- Global font size increase chosen over per-component tweaks to keep consistency across pages.
- No UI/theme/icon packages beyond Tailwind + Lucide React unless explicitly requested.
- `.bolt/prompt` contains authoritative global design and code conventions (not restated here).

## Open questions & assumptions

- Exact base font-size tokens/variables used for the global bump not yet confirmed.
- No design system or typography scale documented yet; assume Tailwind defaults unless noted.
- App domain (e.g. scheduling, clinic, logistics) not explicitly confirmed despite booking/reports pages.