Option.getUnsafe(None)
Option.getUnsafe(Some(42))
try Belt.Option.getUnsafe(None) catch { | _ => 0 }
Console.log(Obj.magic(Array.getUnsafe(values, 0)))
