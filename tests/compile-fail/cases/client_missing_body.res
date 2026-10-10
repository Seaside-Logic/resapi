// expect: TestApi.newAccount vs unit
// createAccount requires a body, so the bodyless `call` is rejected.
open ResApi
let call = client => client->Client.call(TestApi.createAccount, ~params=())
