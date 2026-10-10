// expect: This variant pattern is expected to have type TestApi.accountError
// The client's Application error has the contract's error type.
open ResApi
let describe = async client =>
  switch await client->Client.call(TestApi.getAccount, ~params={id: "a1"}) {
  | Ok(_) => "ok"
  | Error(Application({error: Gone})) => "gone"
  | Error(_) => "other"
  }
