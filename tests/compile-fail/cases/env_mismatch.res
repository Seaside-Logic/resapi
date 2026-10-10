// expect: otherEnv vs env
// Middleware written for a different environment can't be added to the router.
open ResApiHono
type env = {apiSecret: string}
type otherEnv = {region: string}
let regional: Router.middleware<otherEnv> = async (ctx, next) => {
  Console.log((ctx->Context.env).region)
  await next()
  None
}
let app: Router.t<env> = Router.make()->Router.use(regional)
