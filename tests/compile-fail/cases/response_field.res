// expect: The field nme does not belong to type TestApi.account
// Decoded responses have the contract's response type.
let name = json => TestApi.getAccount.responseCodec.decode(json)->Result.map(a => a.nme)
