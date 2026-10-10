// Core and Sury with no server adapter: the typed client against a fake fetch.
open ResApi
open Check

let client = (status, body) =>
  Client.make(~baseUrl="https://api.test", ~fetch=async _request =>
    Fetch.Response.text(body, ~init={status: status})
  )

let main = async () => {
  let ok = await client(200, `{"id":"a1","name":"Ann"}`)->Client.call(
    Api.getAccount,
    ~params={id: "a1"},
  )
  check(ok == Ok({id: "a1", name: "Ann"}), "Ok response decodes")

  let notFound = await client(404, `{"applicationError":"not_found"}`)->Client.call(
    Api.getAccount,
    ~params={id: "x"},
  )
  check(
    switch notFound {
    | Error(Application({status: 404, error: NotFound})) => true
    | _ => false
    },
    "declared error decodes",
  )

  let invalid = await client(200, `{"id":"a1","name":1}`)->Client.call(
    Api.getAccount,
    ~params={id: "a1"},
  )
  check(
    switch invalid {
    | Error(InvalidResponse({path: ["name"]})) => true
    | _ => false
    },
    "invalid response is reported at its field",
  )
  Console.log("ok - sury-client")
}

main()->ignore
