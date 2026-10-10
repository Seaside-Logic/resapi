// expect: The field name does not belong to type TestApi.params
// Decoded params only have `id`.
open ResApiHono
let route = TestApi.getAccount->EndpointHandler.make(async (_ctx, {params}) =>
  Ok({TestApi.id: params.name, name: "n"})
)
