# LSP Performance Measurements

## Method

The development executable `scripts/benchmark_lsp.exe` uses the repository's
typed LSP/JSON-RPC libraries and framing adapter to drive a real release process.
It measures spawn-to-initialize, one open, then 20 sequential full-document
changes with increasing versions. Every response is checked for the expected
document/version. Shutdown/exit must succeed and stderr must remain empty.

```sh
opam exec -- dune build scripts/benchmark_lsp.exe
_build/default/scripts/benchmark_lsp.exe /absolute/path/to/frozen/release/binary
```

Use a frozen binary outside Dune's mutable build directory when compiling other
work. The first exploratory run was discarded because a concurrent Dune build
replaced that path between subprocess starts. The reported baseline below ran
without concurrent builds. Wall-clock timings use `Unix.gettimeofday`; these are
local development measurements, not controlled release-platform certification.

Fixtures have 500, 2,000 or 5,000 physical lines: distinct constant bindings,
one syntax error followed by bindings, flat JSX images with alt text, named
custom hooks, and annotated throws functions separated by blank lines. JSX
enables the React DOM adapter and only `jsx-a11y/alt-text`; other fixtures use
defaults. Clean fixture families emit zero diagnostics; invalid emits one.
No project disk index, compiler or npm operation is included in change latency.

## Baseline: eb5d800

Measured 2026-09-21 on Linux 7.1.13-2-MANJARO, x86_64, Intel Core Ultra 7 355,
eight logical CPUs. Frozen release SHA256:
`852c96584ca1a1207e8c8aec58a3d4c3e9b99f9471a3368b2987d42bdc7405eb`.

All numbers below are milliseconds. Startup ranged from 26.8 to 41.6 ms,
below the proposed 150 ms target. Large document changes exceeded the proposed
50 ms p95 target, especially JSX.

| Fixture | Lines | Open | Change Median | Change p95 |
| --- | ---: | ---: | ---: | ---: |
| Clean | 500 | 13.832 | 10.169 | 12.589 |
| Invalid | 500 | 7.900 | 1.477 | 2.660 |
| JSX | 500 | 88.522 | 71.089 | 78.422 |
| Hooks | 500 | 19.886 | 14.889 | 15.808 |
| Throws | 500 | 12.435 | 7.717 | 9.502 |
| Clean | 2,000 | 34.368 | 27.945 | 30.876 |
| Invalid | 2,000 | 11.330 | 5.629 | 10.508 |
| JSX | 2,000 | 987.003 | 964.935 | 1,082.099 |
| Hooks | 2,000 | 74.859 | 57.281 | 67.225 |
| Throws | 2,000 | 30.495 | 23.674 | 32.575 |
| Clean | 5,000 | 78.486 | 81.217 | 87.210 |
| Invalid | 5,000 | 23.046 | 17.521 | 20.632 |
| JSX | 5,000 | 7,476.170 | 7,433.060 | 7,999.852 |
| Hooks | 5,000 | 151.300 | 139.495 | 151.018 |
| Throws | 5,000 | 67.313 | 59.088 | 63.364 |

## Follow-Up

Read-only inspection found that selecting one JSX rule ran all three JSX/React
packs, including a disabled semantic pass with quadratic expression lookups.
Label/media checks also scanned all descendants for irrelevant image tags.
Scoped fixes and enabled-rule regression tests are underway, followed by a
repeat benchmark. Disabled expression/policy traversals are also being gated
using authoritative rule-family inventories. No performance target or lint/test
threshold has been weakened. Background scheduling remains a separate design
decision after measuring the corrected analysis path.

## Optimized Analysis

Release SHA256:
`674cb885c154722e0d1b6b3287324acd5a86ca950bd22266c42283506f8b9535`.
Same harness, host and fixture sizes, again without concurrent builds. Startup
ranged from 27.5 to 43.5 ms. Diagnostics were unchanged. The baseline binary was
18,437,040 bytes; current size is recorded in the release verification log.

| Fixture | Lines | Open | Change Median | Change p95 |
| --- | ---: | ---: | ---: | ---: |
| Clean | 500 | 17.129 | 9.582 | 11.837 |
| Invalid | 500 | 7.211 | 1.138 | 1.524 |
| JSX | 500 | 22.750 | 17.230 | 19.823 |
| Hooks | 500 | 22.011 | 15.071 | 16.090 |
| Throws | 500 | 12.424 | 7.787 | 8.770 |
| Clean | 2,000 | 45.769 | 30.532 | 38.334 |
| Invalid | 2,000 | 12.259 | 6.488 | 10.472 |
| JSX | 2,000 | 57.066 | 48.911 | 52.864 |
| Hooks | 2,000 | 74.291 | 56.427 | 63.195 |
| Throws | 2,000 | 34.542 | 26.624 | 28.107 |
| Clean | 5,000 | 80.471 | 77.797 | 86.324 |
| Invalid | 5,000 | 23.348 | 16.889 | 20.445 |
| JSX | 5,000 | 134.982 | 134.656 | 145.336 |
| Hooks | 5,000 | 150.567 | 144.732 | 150.609 |
| Throws | 5,000 | 72.289 | 62.369 | 64.670 |

The 5,000-line JSX p95 improves by approximately 55 times. The other families are
largely unchanged within local measurement noise. This is not a claim that the
50 ms large-file target is met: several cases still exceed it. A bounded
latest-version scheduling design is being evaluated separately to avoid queued
obsolete work during rapid edits. It cannot make one individual analysis free.
