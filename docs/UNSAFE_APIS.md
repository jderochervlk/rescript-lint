# Unsafe API Inventory

`no-unsafe` uses explicit qualified paths from ReScript **12.3.1**, pinned at `679406560d169f1124653ab50795d5077570f078`. It does not classify arbitrary functions by a substring in their name. Its implementation is `lib/no_unsafe.ml`.

## Modern standard library

Each module below is recognized as `Module`, `Stdlib.Module`, and `Stdlib_Module`.

| Module | Banned exports |
| --- | --- |
| `Option`, `Null`, `Nullable`, `Dict` | `getUnsafe` |
| `Object` | `getSymbolUnsafe` |
| `Array` | `getUnsafe`, `setUnsafe`, `unsafe_get`, `joinUnsafe`, `joinWithUnsafe`, `getSymbolUnsafe` |
| `String` | `getUnsafe`, `charCodeAtUnsafe`, `getSymbolUnsafe`, `unsafeReplaceRegExpBy0` through `unsafeReplaceRegExpBy3`, `replaceRegExpBy0Unsafe` through `replaceRegExpBy3Unsafe` |

`Array.makeUninitializedUnsafe`, `Array.truncateToLengthUnsafe`, `Array.swapUnsafe`, and `List.unsafeMutateTail` are implementation helpers hidden by the pinned `.resi` files. They are not exported standard APIs and are not included. `Belt.Array` has a different public interface.

## Legacy JavaScript APIs

Both the `Js` path and the direct implementation module are recognized.

| `Js` path | Implementation module | Banned exports |
| --- | --- | --- |
| `Js.Null` | `Js_null` | `getUnsafe` |
| `Js.Undefined` | `Js_undefined` | `getUnsafe` |
| `Js.Array` | `Js_array` | `unsafe_get`, `unsafe_set` |
| `Js.Array2` | `Js_array2` | `unsafe_get`, `unsafe_set` |
| `Js.Dict` | `Js_dict` | `unsafeGet`, `unsafeDeleteKey` |
| `Js.Json` | `Js_json` | `deserializeUnsafe` |
| `Js.Date` | `Js_date` | `toJSONUnsafe` |
| `Js.Math` | `Js_math` | `unsafe_ceil_int`, `unsafe_ceil`, `unsafe_floor_int`, `unsafe_floor`, `unsafe_round`, `unsafe_trunc` |
| `Js.String` | `Js_string` | `unsafeReplaceBy0` through `unsafeReplaceBy3` |
| `Js.String2` | `Js_string2` | `unsafeReplaceBy0` through `unsafeReplaceBy3` |
| `Js.Promise2` | `Js_promise2` | `unsafe_async`, `unsafe_await` |

Also banned: `Js.unsafe_lt`, `Js.unsafe_le`, `Js.unsafe_gt`, `Js.unsafe_ge`, and `Js_OO.unsafe_to_method`. There is no `Js.OO` module alias in the pinned `Js.res`.

The rule recognizes `unsafe_get` and `unsafe_set` in the `Int8Array`, `Uint8Array`, `Uint8ClampedArray`, `Int16Array`, `Uint16Array`, `Int32Array`, `Uint32Array`, `Float32Array`, and `Float64Array` submodules under these roots:

- `Js.Typed_array` and `Js_typed_array`
- `Js.TypedArray2` and `Js_typed_array2`

The older `Typed_array` family additionally exports `Int32_array`, `Float32_array`, and `Float64_array` aliases, which are included. Newer modern typed-array APIs are not assumed to have these legacy names.

## Belt APIs

| Module paths | Banned exports |
| --- | --- |
| `Belt.Option`, `Belt_Option` | `getUnsafe` |
| `Belt.Array`, `Belt_Array` | `getUnsafe`, `setUnsafe`, `makeUninitializedUnsafe`, `truncateToLengthUnsafe`, `blitUnsafe` |
| `Belt.Set`, `Belt_Set` | `fromSortedArrayUnsafe` |
| `Belt.MutableSet`, `Belt_MutableSet` | `fromSortedArrayUnsafe` |

`fromSortedArrayUnsafe` is also recognized in `Belt.Set.Int`, `.String`, and `.Dict`, and `Belt.MutableSet.Int` and `.String`. Their aliases under `Belt_Set`/`Belt_MutableSet`, and direct modules such as `Belt_SetInt` and `Belt_MutableSetString`, are included. Nonexistent paths such as `Belt.SetInt` are not invented.

## Other legacy exports

- `Char.unsafe_chr`
- `Pervasives.__unsafe_cast`
- `Pervasives.unsafe_char_of_int`

Runtime internals such as `Primitive_*` and `Belt_internal*` are outside this inventory. `Obj.magic` and its inventoried equivalent exports have the separate `no-object-magic` rule.

## Verification and limits

`test/no_unsafe_inventory_test.ml` parses the selected runtime `.resi` files, or `.res` files where no interface exists. It compares their public value declarations with the rule's classifications. It checks all unsafe-named members in those selected modules and confirms other members are not classified as unsafe. It reads AST declarations, so documentation examples and private function bodies do not become exports. Behavior and CLI tests separately exercise calls, aliases, handlers, shadowing, source ranges, and all three rules together.

The inventory is a policy for these named exports, not a complete analysis of unsafe behavior. Project configuration, custom functions, module alias/open resolution, unqualified globals, and additional internal APIs remain future work. Checked APIs such as `Array.get`, `Dict.get`, and ordinary option pattern matching are not banned. Catching an error does not exempt a banned reference.
