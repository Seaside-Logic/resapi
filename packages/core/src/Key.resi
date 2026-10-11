// A typed name for a value that middleware stores on a request and handlers read back, through the
// adapters' `Context.set/get` (Hono) and `Req.set/get` (Express). The type is a declaration, not a proof:
// resAPI trusts whoever stored the value to have used this type, as with any external binding.

type t<'a>

/** Annotate the type when you make one: `let userKey: Key.t<User.t> = Key.make("user")`. The name is
    the framework's own: Hono's `c.set`/`c.get` name, or the property on Express's `req`. So
    `Key.make("jwtPayload")` reads what hono/jwt sets, and `Key.make("user")` reads Passport's `req.user`. */
let make: string => t<'a>

let name: t<'a> => string
