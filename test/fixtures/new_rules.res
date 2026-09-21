%debugger

let redundant = try work() catch {
| error => throw(error)
}
