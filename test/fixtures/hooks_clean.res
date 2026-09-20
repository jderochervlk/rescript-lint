let useCounter = () => React.useState(() => 0)

@react.component
let make = (~enabled, ~promise) => {
  let (count, _) = useCounter()
  if enabled {
    ignore(React.use(promise))
  }
  let label = if enabled {"enabled"} else {"disabled"}
  let title = React.useMemo(() => label, [label])
  <div title>{React.int(count)}</div>
}
