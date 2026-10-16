# Testing

How to run the typed client against your server in tests, on Hono and Express.

<div data-framework="hono">

<p class="framework-label"><strong>Hono</strong></p>

`Client.make` takes a `~fetch` function. Pass the router's own fetch (`Router.fetch(app, request, env)`) to run the client against the server in-process, with no server running:

```rescript
let client = Client.make(~baseUrl="http://localhost", ~fetch=request => App.app->Router.fetch(request, ()))
```

Under Node, this exercises routing, middleware, validation and codecs. It doesn't enforce Workers restrictions: a codec built inside a handler works under Node and fails on Workers. Run the tests against `wrangler dev` as well (see `scripts/test-worker.sh`).

</div>

<div data-framework="express">

<p class="framework-label"><strong>Express</strong></p>

Listen on port 0 to get a free port, then point the client at it:

```rescript
@module("node:events") external once: (ResApiExpress.Router.server, string) => promise<unit> = "once"
@send external address: ResApiExpress.Router.server => {"port": int} = "address"

let server = App.app->ResApiExpress.Router.listen(0, () => ())
await once(server, "listening")
let client = Client.make(~baseUrl=`http://localhost:${(server->address)["port"]->Int.toString}`)
```

Call `server->ResApiExpress.Router.close` when the tests finish.

</div>
