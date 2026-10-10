// expect: compiles
// Control: proves the harness compiles valid code, so the failures below are real.
// Contracts import into plain code and their codec types are inferred from the contract.
let accountName = json => TestApi.getAccount.responseCodec.decode(json)->Result.map(a => a.name)
let paramsJson = TestApi.getAccount.paramsCodec.encode({id: "acct_123"})
let bodyJson = TestApi.createAccount.bodyCodec.encode({name: "n"})
