// expect: Cannot create values of the private type ResApi.Endpoint.t
// Contracts are built with Endpoint.get/post, which check the route. A record literal would skip that.
open ResApi
let contract: Endpoint.t<TestApi.params, unit, TestApi.account, Endpoint.noError> = {
  method: Get,
  path: "/anything",
  paramsCodec: TestApi.paramsCodec,
  bodyCodec: Codec.unit,
  responseCodec: TestApi.accountCodec,
  errorCodec: {decode: _ => Error({path: [], message: ""}), encode: _ => JSON.Null},
  errorStatus: _ => 500,
}
