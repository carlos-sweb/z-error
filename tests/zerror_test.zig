const std = @import("std");
const testing = std.testing;
const zerror = @import("zerror");
const ZError = zerror.ZError;
const ErrorKind = zerror.ErrorKind;

test "ZError(JSValue-like generic) works with a non-trivial T" {
    const Pair = struct { a: i32, b: i32 };

    const allocator = testing.allocator;
    var err = try ZError(Pair).initAggregate(allocator, "batch failed", &[_]Pair{
        .{ .a = 1, .b = 2 },
        .{ .a = 3, .b = 4 },
    });
    defer err.deinit();

    try testing.expectEqual(@as(usize, 2), err.errors.?.len);
    try testing.expectEqual(@as(i32, 3), err.errors.?[1].a);
}

test "each ErrorKind constructs and stringifies independently" {
    const allocator = testing.allocator;
    const kinds = [_]ErrorKind{
        .generic,         .type_error, .range_error, .syntax_error,
        .reference_error, .eval_error, .uri_error,
    };
    for (kinds) |kind| {
        var err = try ZError(i32).init(allocator, kind, "x");
        defer err.deinit();
        const s = try err.toString(allocator);
        defer allocator.free(s);

        var expected_buf: [64]u8 = undefined;
        const expected = try std.fmt.bufPrint(&expected_buf, "{s}: x", .{kind.name()});
        try testing.expectEqualStrings(expected, s);
    }
}
