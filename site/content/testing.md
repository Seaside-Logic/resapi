# Testing

Use the typed client in your tests to check requests and responses against the same contracts as your application. The setup differs between Hono and Express.

<div data-framework="hono">

<p class="framework-label"><strong>Hono</strong></p>

`Client.make` accepts a custom `~fetch` function. Use `Router.fetch(app, request, env)` to send requests directly to the Hono app in the same process, without starting an HTTP server:

```rescript
let client = Client.make(~baseUrl="http://localhost", ~fetch=request => App.app->Router.fetch(request, ()))
```

This tests routing, middleware, validation, and codecs under Node. To check Workers restrictions as well, run tests against `wrangler dev` (see `scripts/test-worker.sh`). For example, building a codec inside a handler works under Node but fails on Workers.

</div>

<div data-framework="express">

<p class="framework-label"><strong>Express</strong></p>

Start the Express app on port 0 so Node chooses an available port, then use that port in the client's base URL:

```rescript
@module("node:events") external once: (ResApiExpress.Router.server, string) => promise<unit> = "once"
@send external address: ResApiExpress.Router.server => {"port": int} = "address"

let server = App.app->ResApiExpress.Router.listen(0, () => ())
await once(server, "listening")
let client = Client.make(~baseUrl=`http://localhost:${(server->address)["port"]->Int.toString}`)
```

Close the server with `server->ResApiExpress.Router.close` when the tests finish.

</div>
