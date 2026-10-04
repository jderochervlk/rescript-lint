let check ~emit ~boundary scope flag bindings =
  if flag = Asttypes.Nonrecursive then
    List.iter (Eta_reduction.eta ~emit ~boundary scope) bindings;
  if flag = Asttypes.Recursive then (
    List.iter (Only_used_in_recursion.parameter_forwarding ~emit scope) bindings;
    No_redundant_mutual_recursion.mutual ~emit scope bindings;
    List.iter (Prefer_standard_combinator.manual_map ~emit scope) bindings)
