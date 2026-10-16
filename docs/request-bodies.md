# Request bodies

How resAPI reads the body of a typed POST, and how to limit its size, on Hono and Express. Failures and their responses are listed in [Errors](errors.md#on-the-server).

**Content type.** A typed POST accepts any content type, as long as the body is valid JSON: `application/json`, `text/plain`, none at all. resAPI never answers 415 itself.

<div data-framework="hono">

<p class="framework-label"><strong>Hono</strong></p>

resAPI reads a typed POST's body itself (`c.req.text()`), only after the path params have decoded.

**Size limit.** resAPI sets none, and Workers caps request bodies per plan. For your own limit, mount Hono's `bodyLimit` in front of the typed routes:

```rescript
type bodyLimitOptions = {maxSize: int}
@module("hono/body-limit")
external bodyLimit: bodyLimitOptions => Router.middleware<'env> = "bodyLimit"

let app: Router.t<unit> =
  Router.make()
  ->Router.use(~path="/accounts/*", BearerAuth.requireToken)
  ->Router.use(~path="/accounts/*", bodyLimit({maxSize: 1024}))
```

It answers an oversized body with Hono's plain-text 413, which the client sees as `UnexpectedStatus`, whether or not the request sends a `content-length`. Mounted after the auth middleware, it only runs for authenticated requests.

</div>

<div data-framework="express">

<p class="framework-label"><strong>Express</strong></p>

`Router.register` puts a raw-text body parser in front of each typed POST route, so resAPI parses the JSON itself and reports problems in its own format.

- **Don't mount body parsers globally in front of typed routes.** resAPI parses typed routes' bodies itself. An upstream `express.json()` works, and resAPI uses the body it parsed. But that parser's failures are answered by Express in Express's format, before any of your auth middleware runs if it's mounted later. Scope parsers to the plain routes that need them, for example `Router.use(~path="/webhooks", json())`.
- **Size limit.** The built-in parser keeps Express's default limit of 100kb, and an oversized body is a 413 from Express. To change the limit, mount your own parser ahead of the typed routes, for example `express.text({type: () => true, limit: "1mb"})`. resAPI uses a body that has already been read.
- **Order.** Your middleware runs first. Then `register`'s own body parser reads the body, and resAPI decodes params, then the body. A request your auth middleware rejects is never read.

</div>
