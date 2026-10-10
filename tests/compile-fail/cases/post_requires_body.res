// expect: Missing arguments that must be provided: ~body
// A POST contract must declare its body codec.
open ResApi
let contract = Endpoint.post("/accounts", ~params=Codec.unit, ~response=TestApi.accountCodec)
