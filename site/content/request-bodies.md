# Request bodies

This page explains how resAPI reads request bodies for typed POST endpoints on Hono and Express, and how to set size limits. See [Errors](errors.md#on-the-server) for the possible failures and their responses.

**Content type.** A typed POST accepts any content type as long as the body is valid JSON. The request can use `application/json`, `text/plain`, or no content type at all. resAPI itself never returns HTTP 415.

<div data-framework="hono">

<p class="framework-label"><strong>Hono</strong></p>

resAPI reads the request body with `c.req.text()` after successfully decoding the path parameters.

**Size limit.** resAPI doesn't set a body size limit. Cloudflare Workers applies a limit based on your plan. To set your own limit, register Hono's `bodyLimit` middleware before the typed routes:

```rescript
type bodyLimitOptions = {maxSize: int}
@module("hono/body-limit")
external bodyLimit: bodyLimitOptions => Router.middleware<'env> = "bodyLimit"

let app: Router.t<unit> =
  Router.make()
  ->Router.use(~path="/accounts/*", BearerAuth.requireToken)
  ->Router.use(~path="/accounts/*", bodyLimit({maxSize: 1024}))
```

The middleware returns a plain-text HTTP 413 for oversized bodies, whether or not the request includes a `content-length` header. The client reports this as `UnexpectedStatus`. In this example, the size check runs after authentication, so it only reads bodies from authenticated requests.

</div>

<div data-framework="express">

<p class="framework-label"><strong>Express</strong></p>

`Router.register` adds a raw-text body parser before each typed POST handler. resAPI then parses the JSON and reports validation errors in its own format.

- **Scope body parsers to the routes that need them.** resAPI already parses these bodies. If you register `express.json()` first, resAPI uses its parsed result, but Express handles any parser failures in its own format. Those failures also occur before any auth middleware registered after the parser. Prefer to scope parsers to the plain routes that need them, for example `Router.use(~path="/webhooks", json())`.
- **Size limit.** The built-in parser uses Express's default limit of 100kb. Express returns HTTP 413 if the body exceeds it. To change the limit, register your own parser before the typed routes, for example `express.text({type: () => true, limit: "1mb"})`. resAPI uses the body that parser has already read.
- **Order.** Middleware registered before the route runs first, followed by the body parser added by `register`. resAPI then decodes the path parameters and the body. If your auth middleware rejects the request before the parser runs, the body is never read.

</div>
