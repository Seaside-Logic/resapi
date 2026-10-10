// expect: Some required record fields are missing: member.
// Every path param in the contract's params type must be supplied.
open ResApi
let call = client => client->Client.call(TestApi.getMember, ~params={org: "acme"})
