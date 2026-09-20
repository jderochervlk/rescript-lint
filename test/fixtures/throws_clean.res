exception Missing
exception Invalid(string)

@throws([Missing, Invalid])
let read = () => 0

let fetch = read
let caught = try fetch() catch {
| Missing => 0
| Invalid(_) => 0
}

let matched = switch read() {
| value => Ok(value)
| exception Missing | exception Invalid(_) => Error(#Failed)
}
