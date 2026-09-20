@val external read: unit => int = "read"
let value = read()->convert
switch value {
| _ => consume(value)
}
done()
