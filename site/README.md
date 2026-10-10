# resapi.dev

The landing page, as static files in `public/`, served by Cloudflare Workers static assets.

```bash
npx wrangler dev      # preview on http://localhost:8787
npx wrangler deploy   # publish to resapi.dev (a maintainer step)
```

`wrangler.jsonc` attaches the Worker to `resapi.dev` as a custom domain. To send `www.resapi.dev` to the apex, add a Cloudflare redirect rule (Rules → Redirect Rules, "Redirect from WWW to root"). The page's code samples are copied from the root README, whose examples `npm run check:packages` compiles. Keep the two in step.
