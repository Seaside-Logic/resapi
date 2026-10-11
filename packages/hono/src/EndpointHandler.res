// Turns a contract into a route: the request runs through core's Dispatch pipeline, and the result is
// sent as a Fetch Response. The handler's types are closed over, so routes of any contract types share one type.
open ResApi

type input<'params, 'body> = Dispatch.input<'params, 'body> = {params: 'params, body: 'body}

type handler<'env, 'params, 'body, 'response, 'error> = (
  Context.t<'env>,
  input<'params, 'body>,
) => promise<result<'response, 'error>>

type route<'env> = {
  method: Endpoint.method,
  path: string,
  run: Context.t<'env> => promise<Fetch.Response.t>,
}

let make = (contract: Endpoint.t<_, _, _, _>, handler: handler<_, _, _, _, _>) => {
  method: contract.method,
  path: contract.path,
  run: async ctx => {
    let {status, body} = await Dispatch.run(
      contract,
      ~params=ctx->Context.params,
      ~readBody=() => Text(ctx->Context.text),
      ~handle=input => handler(ctx, input),
    )
    Fetch.Response.jsonR(~data=body, ~init={status: status})
  },
}
