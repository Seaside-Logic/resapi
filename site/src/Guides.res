/** The guides: the repo's Markdown docs, bundled as strings. GuidePage renders the title, so the
Markdown's own `# Title` line is dropped from the body. */

type section = Guides | Reference

type t = {
  slug: string,
  title: string,
  summary: string,
  section: section,
  body: string,
}

@module("../../docs/getting-started.md?raw") external gettingStarted: string = "default"
@module("../../docs/middleware.md?raw") external middleware: string = "default"
@module("../../docs/request-bodies.md?raw") external requestBodies: string = "default"
@module("../../docs/routing.md?raw") external routing: string = "default"
@module("../../docs/testing.md?raw") external testing: string = "default"
@module("../../docs/errors.md?raw") external errors: string = "default"
@module("../../docs/api.md?raw") external api: string = "default"
@module("../../docs/architecture.md?raw") external architecture: string = "default"

let withoutTitle = markdown => markdown->String.replaceRegExp(/^# .*\n+/, "")

let all = [
  {
    slug: "getting-started",
    title: "Getting started",
    summary: "Build a typed endpoint, serve it from Hono or Express, and call it from a typed client.",
    section: Guides,
    body: gettingStarted,
  },
  {
    slug: "middleware",
    title: "Middleware and auth",
    summary: "Framework middleware, and protecting endpoints with Reject and typed keys.",
    section: Guides,
    body: middleware,
  },
  {
    slug: "request-bodies",
    title: "Request bodies",
    summary: "How typed POST bodies are read, which content types work, and how to limit their size.",
    section: Guides,
    body: requestBodies,
  },
  {
    slug: "routing",
    title: "Routing",
    summary: "Plain routes, other libraries and not-found handlers beside typed endpoints.",
    section: Guides,
    body: routing,
  },
  {
    slug: "testing",
    title: "Testing",
    summary: "Call your server from the typed client in tests.",
    section: Guides,
    body: testing,
  },
  {
    slug: "errors",
    title: "Errors",
    summary: "Invalid requests, application errors, server and client failures, how each is reported, and reading type errors.",
    section: Guides,
    body: errors,
  },
  {
    slug: "api",
    title: "API reference",
    summary: "The public API of every package.",
    section: Reference,
    body: api,
  },
  {
    slug: "architecture",
    title: "Architecture",
    summary: "The design of resAPI and the reasons behind each decision.",
    section: Reference,
    body: architecture,
  },
]->Array.map(guide => {...guide, body: withoutTitle(guide.body)})

/** Whether the guide has Hono and Express versions of some sections. */
let hasFrameworks = guide => guide.body->String.includes("<div data-framework=")

let inSection = section => all->Array.filter(guide => guide.section == section)

let find = slug => all->Array.find(guide => guide.slug == slug)
