/** Plain-Markdown copies of the site for AI coding agents, following https://llmstxt.org.
`vite.config.js` emits each file at its path, so `/guides/errors` has a Markdown twin at
`/guides/errors.md`, with `/llms.txt` indexing them and `/llms-full.txt` joining them. */

let summary = "resAPI is a contract-first HTTP toolkit for ReScript: define an endpoint once as a value, then serve it with Hono or Express and call it from a typed client, with validation at both ends."

let details = `Key facts for writing code against resAPI:

- Packages: \`@resapi/core\` (contracts, codecs, typed client; namespace \`ResApi\`), \`@resapi/hono\` (namespace \`ResApiHono\`), \`@resapi/express\` (namespace \`ResApiExpress\`, Express 5 only), \`@resapi/sury\` (Sury schemas as codecs).
- Install for Hono: \`npm install @resapi/core @resapi/hono @resapi/sury hono sury sury-ppx\`. For Express, swap \`@resapi/hono hono\` for \`@resapi/express express\`. List the packages and \`sury\` in \`rescript.json\` \`dependencies\`, with \`"ppx-flags": ["sury-ppx/bin"]\`. Requires ReScript 12.
- A contract is a value: \`Endpoint.get("/accounts/:id", ~params=..., ~response=...)\`, optionally \`->Endpoint.withErrors(codec, ~status=error => ...)\`.
- Servers: \`Router.make()->Router.register(contract->EndpointHandler.make(async (ctx, {params}) => Ok(value)))\`. Handlers return \`Ok(value)\` or \`Error(declaredError)\`.
- Clients: \`client->Client.call(contract, ~params=...)\` returns a result; declared errors arrive as \`Error(Application({error}))\`.
- Guides with Hono and Express versions wrap each version in \`<div data-framework="hono">\` or \`<div data-framework="express">\`.
- Build Sury codecs at module top level: Cloudflare Workers forbid \`new Function\` during a request.`

let siteUrl = "https://resapi.dev"

let mdPath = href => `${href}.md`

let link = (~title, ~href, ~description) => `- [${title}](${siteUrl}${mdPath(href)}): ${description}`

let guideMarkdown = (guide: Guides.t) => `# ${guide.title}

> ${guide.summary}

${guide.body->String.trim}
`

let guidePath = (guide: Guides.t) => Route.toHref(Guide(guide.slug))

let section = (title, guides) =>
  `## ${title}\n\n${guides
    ->Array.map(guide => link(~title=guide.Guides.title, ~href=guidePath(guide), ~description=guide.summary))
    ->Array.join("\n")}`

let intro = `# resAPI\n\n> ${summary}\n\n${details}`

let index = [
  intro,
  section("Guides", Guides.inSection(Guides)),
  section("Reference", Guides.inSection(Reference)),
]->Array.join("\n\n")

let pages = Guides.all->Array.map(guide => (mdPath(guidePath(guide)), guideMarkdown(guide)))

let full = [intro, ...pages->Array.map(((_, md)) => md)]->Array.join("\n\n---\n\n")

/** Site path (with leading slash) to file contents. */
let files = [("/llms.txt", index ++ "\n"), ("/llms-full.txt", full), ...pages]
