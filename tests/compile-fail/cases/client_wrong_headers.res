// expect: But it's expected to have type: dict<string>
// Request headers are a dict of names to values.
open ResApi
let call = client =>
  client->Client.call(TestApi.getAccount, ~params={id: "a1"}, ~headers=[("authorization", "x")])
