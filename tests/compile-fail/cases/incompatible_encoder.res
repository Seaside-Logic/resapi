// expect: but a field was expected belonging to the record type TestApi.params
// Contract built with the params codec as its response encoder; the handler returns an account.
open ResApi
open ResApiHono
let contract = Endpoint.get("/accounts/:id", ~params=TestApi.paramsCodec, ~response=TestApi.paramsCodec)
let route = contract->EndpointHandler.make(async (_ctx, _) => Ok({TestApi.id: "a1", name: "n"}))
