// Core, Sury and Express: a typed endpoint on a real Node server, called over HTTP by the typed client.
open ResApi
open ResApiExpress
open Check

@module("node:events") external once: (Router.server, string) => promise<unit> = "once"
@send external address: Router.server => {"port": int} = "address"

let app =
  Router.make()
  ->Router.register(
    Api.getAccount->EndpointHandler.make(async (_req, {params}) =>
      params.id == "a1" ? Ok({id: "a1", name: "Ann"}) : Error(NotFound)
    ),
  )
  ->Router.register(
    Api.createAccount->EndpointHandler.make(async (_req, {body}) => Ok({
      id: "new",
      name: body.name,
    })),
  )

let main = async () => {
  let server = app->Router.listen(0, () => ())
  await once(server, "listening")
  let port = (server->address)["port"]->Int.toString
  let client = Client.make(~baseUrl=`http://localhost:${port}`)

  let ok = await client->Client.call(Api.getAccount, ~params={id: "a1"})
  check(ok == Ok({id: "a1", name: "Ann"}), "typed GET")

  let notFound = await client->Client.call(Api.getAccount, ~params={id: "x"})
  check(
    switch notFound {
    | Error(Application({status: 404, error: NotFound})) => true
    | _ => false
    },
    "typed application error",
  )

  let created = await client->Client.callWithBody(Api.createAccount, ~params=(), ~body={name: "Bo"})
  check(created == Ok({id: "new", name: "Bo"}), "typed POST")

  server->Router.close
  Console.log("ok - express")
}

main()->ignore
