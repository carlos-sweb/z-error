const std = @import("std");
const Allocator = std.mem.Allocator;

/// The 8 standard ECMAScript error kinds (ECMA-262 §20.5).
pub const ErrorKind = enum {
    generic,
    type_error,
    range_error,
    syntax_error,
    reference_error,
    eval_error,
    uri_error,
    aggregate_error,

    /// The spec `.name` a value of this kind reports, e.g. "TypeError".
    pub fn name(self: ErrorKind) []const u8 {
        return switch (self) {
            .generic => "Error",
            .type_error => "TypeError",
            .range_error => "RangeError",
            .syntax_error => "SyntaxError",
            .reference_error => "ReferenceError",
            .eval_error => "EvalError",
            .uri_error => "URIError",
            .aggregate_error => "AggregateError",
        };
    }
};

/// Generic ECMAScript-compatible Error value. Generic over T (the type of
/// AggregateError's aggregated values) so that a consumer like z-value can
/// instantiate ZError(JSValue) — mirrors the ZArray(T)/ZObject(T)/ZMap(K,V)
/// pattern already used across the ecosystem.
pub fn ZError(comptime T: type) type {
    return struct {
        const Self = @This();

        kind: ErrorKind,
        message: []const u8,
        /// Only meaningful for .aggregate_error; null for every other kind.
        errors: ?[]T = null,
        allocator: Allocator,

        /// `message` is duplicated; the caller retains ownership of the
        /// slice it passed in.
        pub fn init(allocator: Allocator, kind: ErrorKind, message: []const u8) !Self {
            return .{
                .kind = kind,
                .message = try allocator.dupe(u8, message),
                .errors = null,
                .allocator = allocator,
            };
        }

        /// `message` and `errs` are both duplicated. This does NOT retain or
        /// otherwise take ownership of the *contents* of `errs` (matching
        /// ZArray(T)/ZMap(K,V)'s own convention of storing T by value as
        /// given) — a caller wrapping T-specific resources (e.g. z-value's
        /// JSValue) is responsible for that at its own layer.
        pub fn initAggregate(allocator: Allocator, message: []const u8, errs: []const T) !Self {
            const owned_message = try allocator.dupe(u8, message);
            errdefer allocator.free(owned_message);
            const owned_errors = try allocator.dupe(T, errs);
            return .{
                .kind = .aggregate_error,
                .message = owned_message,
                .errors = owned_errors,
                .allocator = allocator,
            };
        }

        /// Frees `message` and the `errors` slice itself (not each element's
        /// own resources — same convention as ZArray(T).deinit(), which
        /// doesn't call .deinit() on each T either).
        pub fn deinit(self: *Self) void {
            self.allocator.free(self.message);
            if (self.errors) |errs| self.allocator.free(errs);
        }

        /// Error.prototype.toString(): "name: message", or just "name" if
        /// message is empty.
        pub fn toString(self: *const Self, allocator: Allocator) ![]u8 {
            if (self.message.len == 0) {
                return allocator.dupe(u8, self.kind.name());
            }
            return std.fmt.allocPrint(allocator, "{s}: {s}", .{ self.kind.name(), self.message });
        }
    };
}

test "ErrorKind.name() matches spec names" {
    try std.testing.expectEqualStrings("Error", ErrorKind.generic.name());
    try std.testing.expectEqualStrings("TypeError", ErrorKind.type_error.name());
    try std.testing.expectEqualStrings("RangeError", ErrorKind.range_error.name());
    try std.testing.expectEqualStrings("SyntaxError", ErrorKind.syntax_error.name());
    try std.testing.expectEqualStrings("ReferenceError", ErrorKind.reference_error.name());
    try std.testing.expectEqualStrings("EvalError", ErrorKind.eval_error.name());
    try std.testing.expectEqualStrings("URIError", ErrorKind.uri_error.name());
    try std.testing.expectEqualStrings("AggregateError", ErrorKind.aggregate_error.name());
}

test "init/deinit: message is duplicated, no leak" {
    const allocator = std.testing.allocator;
    var buf: [11]u8 = "bad request".*;
    var err = try ZError(i32).init(allocator, .type_error, buf[0..]);
    defer err.deinit();

    buf[0] = 'X'; // mutate the caller's buffer after init
    try std.testing.expectEqualStrings("bad request", err.message);
}

test "toString with and without a message" {
    const allocator = std.testing.allocator;

    var with_msg = try ZError(i32).init(allocator, .range_error, "out of bounds");
    defer with_msg.deinit();
    const s1 = try with_msg.toString(allocator);
    defer allocator.free(s1);
    try std.testing.expectEqualStrings("RangeError: out of bounds", s1);

    var without_msg = try ZError(i32).init(allocator, .generic, "");
    defer without_msg.deinit();
    const s2 = try without_msg.toString(allocator);
    defer allocator.free(s2);
    try std.testing.expectEqualStrings("Error", s2);
}

test "initAggregate: errors slice is duplicated, no leak" {
    const allocator = std.testing.allocator;
    var source = [_]i32{ 1, 2, 3 };
    var err = try ZError(i32).initAggregate(allocator, "multiple failures", source[0..]);
    defer err.deinit();

    source[0] = 999; // mutate the caller's slice after init
    try std.testing.expectEqual(@as(i32, 1), err.errors.?[0]);
    try std.testing.expectEqual(@as(usize, 3), err.errors.?.len);
    try std.testing.expectEqual(ErrorKind.aggregate_error, err.kind);
}

test "aggregate error with an empty errors list" {
    const allocator = std.testing.allocator;
    var err = try ZError(i32).initAggregate(allocator, "none", &[_]i32{});
    defer err.deinit();
    try std.testing.expectEqual(@as(usize, 0), err.errors.?.len);
}

test "non-aggregate errors have errors == null" {
    const allocator = std.testing.allocator;
    var err = try ZError(i32).init(allocator, .syntax_error, "oops");
    defer err.deinit();
    try std.testing.expect(err.errors == null);
}
