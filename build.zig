const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zerror_module = b.addModule("zerror", .{
        .root_source_file = b.path("src/zerror.zig"),
        .target = target,
        .optimize = optimize,
    });

    const docs_library = b.addLibrary(.{
        .name = "zerror",
        .root_module = zerror_module,
    });
    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs_library.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    const docs_step = b.step("docs", "Generate native Zig API documentation");
    docs_step.dependOn(&install_docs.step);

    const test_step = b.step("test", "Run all tests");

    const test_files = [_][]const u8{
        "tests/zerror_test.zig",
    };

    inline for (test_files) |test_file| {
        const unit_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(test_file),
                .target = target,
                .optimize = optimize,
            }),
        });

        unit_tests.root_module.addImport("zerror", zerror_module);

        const run_unit_tests = b.addRunArtifact(unit_tests);
        test_step.dependOn(&run_unit_tests.step);
    }

    // Also run the tests inlined in src/zerror.zig itself.
    const src_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zerror.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_src_tests = b.addRunArtifact(src_tests);
    test_step.dependOn(&run_src_tests.step);

    b.default_step = test_step;
}
