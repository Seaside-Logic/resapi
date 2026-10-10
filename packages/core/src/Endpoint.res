// A contract describes an endpoint's wire format and is safe to share with clients:
// it references no server or runtime code. Server adapters turn contracts into routes.

type method = Get | Post

type t<'params, 'body, 'response> = {
  method: method,
  path: string,
  paramsCodec: Codec.t<'params>,
  bodyCodec: Codec.t<'body>,
  responseCodec: Codec.t<'response>,
}

let get = (path, ~params, ~response) => {
  method: Get,
  path,
  paramsCodec: params,
  bodyCodec: Codec.unit,
  responseCodec: response,
}

let post = (path, ~params, ~body, ~response) => {
  method: Post,
  path,
  paramsCodec: params,
  bodyCodec: body,
  responseCodec: response,
}
