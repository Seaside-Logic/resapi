// expect: TestApi.accountError vs
// An endpoint declares its application errors once.
open ResApi
let contract =
  TestApi.getAccount->Endpoint.withErrors(Codec.unit, ~status=_ => 400)
