# Routing beside typed endpoints

You can use the same router for typed endpoints, plain routes, and other libraries. This page explains how to combine them, handle unmatched requests, and check that every contract has been registered.

- **`Router.all(path, handler)`** adds a plain route for every HTTP method. Use it to pass requests under a path prefix to another library, for example `Router.all("/api/auth/*", ...)` for Better Auth.
- **`Router.assertRegistered(router, endpoints)`** checks that every contract in the list was added with `register`. It throws an exception naming any missing contracts. Keep a list of your contracts (`[AccountApi.getAccount->Endpoint.any, ...]`) and check it in a test to catch missing registrations before they cause unexpected 404 responses.

<div data-framework="hono">

<p class="framework-label"><strong>Hono</strong></p>

- **`Context.request`** gives you the original Fetch `Request` (`c.req.raw`). Pass it to libraries that accept a Fetch request, as in `auth->BetterAuth.handler(ctx->Context.request)`. Use `ResApi.Fetch` types when writing bindings for these libraries.
- **`Router.notFound(handler)`** handles requests that match no route. By default, Hono returns a plain-text 404. You can replace it with a custom response:

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

- **Unmatched requests:** add a `Router.use` handler after all your routes to respond to requests that reach the end. Express has no separate not-found handler.

</div>
