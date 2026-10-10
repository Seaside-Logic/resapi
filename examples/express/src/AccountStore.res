// In-memory accounts, per server process.
open AccountApi

let accounts = dict{
  "acct_123": {id: "acct_123", name: "Retirement Savings", balance: 250000., nickname: None},
}

let get = id => accounts->Dict.get(id)

let create = ({name, balance, nickname}: newAccount) => {
  let id = `acct_${(accounts->Dict.keysToArray->Array.length + 1)->Int.toString}`
  let account = {id, name, balance, nickname}
  accounts->Dict.set(id, account)
  account
}
