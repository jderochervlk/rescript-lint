@throws(Not_found)
let read = () => 0

read()

@throws(Not_found)
let caller = () => read()

let matched = switch read() {
| value => Ok(value)
| exception Not_found => Error(#Missing)
}
