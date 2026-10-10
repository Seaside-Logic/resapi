// expect: But the record field id is expected to have type: string
// The decoded member param is an int; using it as a string id is rejected.
open ResApiHono
let route = TestApi.getMember->EndpointHandler.make(async (_ctx, {params}) =>
  Ok({TestApi.id: params.member, name: "n"})
)
