// expect: But this function argument is expecting: int
// A key's type is fixed when it's made: storing a value of another type doesn't compile.
open ResApiHono
let countKey: ResApi.Key.t<int> = ResApi.Key.make("count")
let middleware: Router.middleware<unit> = async (ctx, next) => {
  ctx->Context.set(countKey, "three")
  await next()
  None
}
