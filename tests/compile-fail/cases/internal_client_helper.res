// expect: The value joinUrl can't be found in Client
// Client's URL helpers are internal: Client.resi exposes only make, call and callWithBody.
open ResApi
let url = Client.joinUrl("https://x.dev", "/a")
