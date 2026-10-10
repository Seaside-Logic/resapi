// expect: The field id does not belong to type TestApi.newAccount
// The create body has no id; only the stored account does.
open ResApiHono
let route = TestApi.createAccount->EndpointHandler.make(async (_ctx, {body}) =>
  Ok({TestApi.id: body.id, name: body.name})
)
