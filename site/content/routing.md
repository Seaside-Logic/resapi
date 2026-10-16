# Routing beside typed endpoints

Typed endpoints share a router with plain routes, other libraries and a not-found handler. This page covers those, and a check that every contract is mounted.

- **`Router.all(path, handler)`** is a plain route for every HTTP method. It's how you hand a prefix to another library, for example `Router.all("/api/auth/*", ...)` for Better Auth.
- **`Router.assertRegistered(router, endpoints)`** throws, naming each listed contract that wasn't mounted with `register`. Keep a list of every contract (`[AccountApi.getAccount->Endpoint.any, ...]`) and call it in a test, so a forgotten `register` fails the test instead of answering 404.

<div data-framework="hono">

<p class="framework-label"><strong>Hono</strong></p>

- **`Context.request`** is the original Fetch `Request` (`c.req.raw`), for libraries that take one: `auth->BetterAuth.handler(ctx->Context.request)`. Bind such libraries against `ResApi.Fetch` types.
- **`Router.notFound(handler)`** answers unmatched requests. Without it, Hono answers a plain-text 404:

```rescript
let app: Router.t<unit> =
  Router.make()->Router.notFound(async _ctx =>
    Fetch.Response.jsonR(
      ~data=JSON.Encode.object(dict{"error": JSON.Encode.string("not_found")}),
      ~init={status: 404},
    )
  )
```

</div>

<div data-framework="express">

<p class="framework-label"><strong>Express</strong></p>

- **Unmatched requests:** add a last `Router.use` that answers them. Express has no separate not-found handler.

</div>
