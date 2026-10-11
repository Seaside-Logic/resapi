// A typed name for a value that middleware stores on a request and handlers read back, through the
// adapters' `Context.set/get` (Hono) and `Req.set/get` (Express). The type is a declaration, not a proof:
// resAPI trusts whoever stored the value to have used this type, as with any external binding.

type t<'a>

/** Annotate the type when you make one: `let userKey: Key.t<User.t> = Key.make("user")`. The name is
    the framework's own: Hono's `c.set`/`c.get` name, or the property on Express's `req`. So
    `Key.make("jwtPayload")` reads what hono/jwt sets, and `Key.make("user")` reads Passport's `req.user`. On Express the name is a property on `req`, so don't reuse one
    of Express's own (`query`, `path`, `params`, `body`...). */
let make: string => t<'a>

let name: t<'a> => string

/** The value an adapter's `get` found, or a JS Error naming the key when there is none. It backs the
    adapters' `getOrThrow`, so the message is the same on every adapter. */
let orThrow: (option<'a>, t<'a>) => 'a
