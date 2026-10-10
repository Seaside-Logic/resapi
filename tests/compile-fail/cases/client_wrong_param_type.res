// expect: This has type: int
// getMember's org param is a string.
open ResApi
let call = client => client->Client.call(TestApi.getMember, ~params={org: 1, member: 2})
