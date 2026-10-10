// expect: The field name does not belong to type TestApi.params
// getAccount's params are {id}, not an arbitrary record.
open ResApi
let call = client => client->Client.call(TestApi.getAccount, ~params={name: "acct_123"})
