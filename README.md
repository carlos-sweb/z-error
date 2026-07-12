# Z-Error

[![Zig Version](https://img.shields.io/badge/zig-0.16-orange.svg)](https://ziglang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

ECMAScript-compatible **Error** types (`Error`, `TypeError`, `RangeError`, `SyntaxError`, `ReferenceError`, `EvalError`, `URIError`, `AggregateError`) in Zig 0.16, part of the [z-*](https://github.com/carlos-sweb) micro-library ecosystem.

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

## License

MIT
