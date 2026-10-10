// Worker bindings. Cloudflare supplies the object; this type is unchecked against it, like any external.
type t = {@as("API_SECRET") apiSecret: string}
