// expect: The field apiKey does not belong to type env
// Bindings are a typed record; a misspelled binding name is caught.
open ResApi
open ResApiHono
type env = {apiSecret: string}
let handler: Router.handler<env> = async ctx => Fetch.Response.text((ctx->Context.env).apiKey)
