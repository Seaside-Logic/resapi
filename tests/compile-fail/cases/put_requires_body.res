// expect: Missing arguments that must be provided: ~body
// A PUT contract must declare its body codec.
open ResApi
let contract = Endpoint.put("/accounts/:id", ~params=TestApi.paramsCodec, ~response=TestApi.accountCodec)
