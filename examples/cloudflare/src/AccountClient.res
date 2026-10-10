// A client for the example API. It uses only the shared contracts, so it bundles without Hono.
open ResApi

let getAccount = (client, id) => client->Client.call(AccountApi.getAccount, ~params={id: id})

let createAccount = (client, newAccount) =>
  client->Client.callWithBody(AccountApi.createAccount, ~params=(), ~body=newAccount)

// What a caller writes: every outcome is a typed case.
let describe = async (client, id) =>
  switch await client->getAccount(id) {
  | Ok(account) => `${account.name}: ${account.balance->Float.toString}`
  | Error(Application({error: NotFound})) => "not found"
  | Error(Network(message)) => `network error: ${message}`
  | Error(Aborted) => "cancelled"
  | Error(InvalidResponse({path, message})) =>
    `invalid response at [${path->Array.join(".")}]: ${message}`
  | Error(UnexpectedStatus({status})) => `unexpected status ${status->Int.toString}`
  | Error(InvalidParams(message) | EncodeFailed(message)) => `bad request: ${message}`
  }
