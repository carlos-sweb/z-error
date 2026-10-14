# Z-Error

[![Zig Version](https://img.shields.io/badge/zig-0.17.0-orange.svg)](https://ziglang.org/)
[![API Docs](https://img.shields.io/badge/API-Zig_Docs-blue.svg)](https://carlos-sweb.github.io/z-error/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

ECMAScript-compatible **Error** types (`Error`, `TypeError`, `RangeError`, `SyntaxError`, `ReferenceError`, `EvalError`, `URIError`, `AggregateError`) in Zig 0.17.0, part of the [z-*](https://github.com/carlos-sweb) micro-library ecosystem.

## Requirements

Zig 0.17.0. The included `mise.toml` pins the development compiler to this version.

## Scope: JavaScript errors, not Zig errors

z-error defines the canonical taxonomy of JavaScript-visible errors (the
8 ECMA-262 kinds: Error, TypeError, RangeError, SyntaxError, ReferenceError,
EvalError, URIError, AggregateError) and the `ZError(T)` struct that represents
a JS Error.

It is NOT a general-purpose Zig error-handling library.

The rule in the z-* ecosystem:

- z-error defines the taxonomy.
- z-* data libraries (z-array, z-object, z-string, z-map, z-set, z-date,
  z-promise, z-bigint, z-buffer, z-temporal, z-symbol, z-number, z-math,
  z-json, z-parser, z-statements, z-functions) propagate Zig error sets for
  internal failures. They do not import z-error and do not produce JS-visible
  errors.
- The interpreter and the host adapters (in z-run) decide when an internal
  failure becomes a JS error, using `ZError(JSValue)` with an `ErrorKind`.
- Not every thrown value is a `ZError`: `throw 123` and
  `Promise.reject("x")` are valid JavaScript.

## Design

- **`ErrorKind`** — an enum for the eight ECMA-262 native error kinds. `.name()` returns the constructor name used in `Error.prototype.toString()` output (`"TypeError"`, etc.).
- **`ZError(comptime T: type)`** — generic over the error-list element type, same shape as `ZArray(T)`/`ZObject(T)`/`ZMap(K, V)` elsewhere in the ecosystem. `errors: ?[]T` is only meaningful for `.aggregate_error`; every other kind leaves it `null`. Generic `T` exists so [z-value](https://github.com/carlos-sweb/z-value) can instantiate `ZError(JSValue)` — `AggregateError.errors` is a list of arbitrary JS values, not a fixed type.
- **Ownership**: `message` is duplicated on `init()`/`initAggregate()`, not borrowed. `initAggregate()` duplicates the `errs` slice itself (a byte-copy, same shallow-copy convention as `ZArray.clone()`) but does **not** retain/clone each `T` — if `T` owns resources, the caller manages their lifetime same as pushing into any other z-* container.
- **`toString()`**: `"name: message"`, or just `"name"` when `message` is empty — matches `Error.prototype.toString()`.

## Usage

```zig
const zerror = @import("zerror");
const ZError = zerror.ZError;

var err = try ZError(void).init(allocator, .type_error, "not a function");
defer err.deinit();

const s = try err.toString(allocator);
defer allocator.free(s);
// s == "TypeError: not a function"

var agg = try ZError(i32).initAggregate(allocator, "batch failed", &[_]i32{ 1, 2, 3 });
defer agg.deinit();
// agg.errors.?.len == 3
```

## Testing

```bash
zig build test
```

## API Documentation

Browse the [native Zig API documentation](https://carlos-sweb.github.io/z-error/) for `ErrorKind`, `ZError(T)`, and their public methods.

Generate the documentation locally with Zig's native build API:

```bash
zig build docs
```

The generated site is written to `zig-out/docs/`. Serve it over HTTP to load the documentation's WebAssembly assets:

```bash
python3 -m http.server 8000 --directory zig-out/docs
```

Then open <http://localhost:8000/>. GitHub Actions generates and publishes this same documentation to GitHub Pages on every push to `master`. Generated files are build artifacts and are not committed to the repository.

## License

MIT
