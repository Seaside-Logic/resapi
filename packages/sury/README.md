# @resapi/sury

[Sury](https://github.com/DZakh/sury) schemas as [resAPI](https://github.com/Seaside-Logic/resapi) codecs.

```sh
npm install @resapi/core @resapi/sury sury
```

Add `"@resapi/core"`, `"@resapi/sury"` and `"sury"` to `dependencies` in `rescript.json`. `SuryCodec.make(schema)` turns a Sury schema into a `ResApi.Codec.t`. Tested with Sury 11.

See the [README](https://github.com/Seaside-Logic/resapi#readme) and [API reference](https://github.com/Seaside-Logic/resapi/blob/main/docs/api.md).
