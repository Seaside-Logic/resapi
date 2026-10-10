// expect: But this function argument ~body is expecting: TestApi.newAccount
// A full account is not the create body, even though it has the same fields and more.
open ResApi
let call = (client, account: TestApi.account) =>
  client->Client.callWithBody(TestApi.createAccount, ~params=(), ~body=account)
