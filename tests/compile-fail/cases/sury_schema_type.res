// expect: string vs int
// A Sury schema's type flows through SuryCodec into the contract.
open ResApi
let contract: Endpoint.t<unit, unit, int, _> = Endpoint.get(
  "/count",
  ~params=Codec.unit,
  ~response=SuryCodec.make(S.string),
)
