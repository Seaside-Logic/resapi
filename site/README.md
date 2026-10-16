# resapi.dev

The docs site: a Vite + ReScript + React app, built to `dist/` and served by Cloudflare Workers static assets. Its layout follows [rescript-radix.dev](https://rescript-radix.dev).

```bash
npm install
npm run dev           # rescript + vite dev server (run `npm run res:watch` alongside to recompile)
npm run build         # compile ReScript and build dist/
npx wrangler dev      # preview dist/ on http://localhost:8787
npx wrangler deploy   # publish to resapi.dev (a maintainer step)
```

Guide pages render `content/*.md` (listed in `src/Guides.res`), so edit the Markdown there. `docs/` at the repo root keeps maintainer-only notes (the release process). `vite.config.js` also emits Markdown copies for AI agents (`/llms.txt`, `/llms-full.txt`, `/guides/<slug>.md`) from `src/LlmsTxt.res`.

`wrangler.jsonc` attaches the Worker to `resapi.dev` as a custom domain. To send `www.resapi.dev` to the apex, add a Cloudflare redirect rule (Rules → Redirect Rules, "Redirect from WWW to root"). The home page's code samples (`src/pages/HomePage.res`) are copied from the root README, whose examples `npm run check:packages` compiles. Keep the two in step.
