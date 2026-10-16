# resapi.dev

The docs site: a Vite + ReScript + React app, built to `dist/`. 

```bash
npm install
npm run dev           # rescript + vite dev server (run `npm run res:watch` alongside to recompile)
npm run build         # compile ReScript and build dist/
```

Guide pages render `content/*.md` (listed in `src/Guides.res`), so edit the Markdown there. `docs/` at the repo root keeps maintainer-only notes (the release process). `vite.config.js` also emits Markdown copies for AI agents (`/llms.txt`, `/llms-full.txt`, `/guides/<slug>.md`) from `src/LlmsTxt.res`.

