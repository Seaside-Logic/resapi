// expect: The field nme does not belong to type CaseApi.account
// Decoded responses have the contract's response type.
let name = json => CaseApi.getAccount.responseCodec.decode(json)->Result.map(a => a.nme)
