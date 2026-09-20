React.useState(() => 0)

@react.component
let make = (~enabled) => {
  if enabled {
    React.useEffect(() => None, [])
  }
  let onClick = () => useCounter()
  onClick
}

let useCounter = () => {
  try React.useState(() => 0) catch {
  | _ => (0, _ => ())
  }
}
