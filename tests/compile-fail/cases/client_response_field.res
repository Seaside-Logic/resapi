// expect: The field nme does not belong to type TestApi.account
// The decoded response has the contract's response type.
open ResApi
let call = async client =>
  switch await client->Client.call(TestApi.getAccount, ~params={id: "acct_123"}) {
  | Ok(account) => account.nme
  | Error(_) => ""
  }
