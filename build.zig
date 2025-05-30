const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const upstream = b.dependency("upstream", .{});

    // Options
    const enable_testing = b.option(bool, "enable_testing", "Enable building tests") orelse true;
    const main_project = b.option(bool, "main_project", "Whether this is the main project") orelse false;

    // Header-only libraries don't need to be built as artifacts
    // They will be installed via the directory installation below

    // Library: libevents_parser
    const libevents_parser = b.addStaticLibrary(.{
        .name = "libevents_parser",
        .target = target,
        .optimize = optimize,
    });
    libevents_parser.addIncludePath(upstream.path("libs/cpp"));
    libevents_parser.linkLibCpp(); // Link C++ standard library
    libevents_parser.addCSourceFiles(.{
        .files = &.{
            "parse/parser.cpp",
        },
        .flags = &.{
            "-Wall",
            "-Wextra",
            "-Werror",
            "-Wconversion",
            "-Wpedantic",
            "-std=c++14",
        },
        .root = upstream.path("libs/cpp"),
    });
    b.installArtifact(libevents_parser);

    // nlohmann_json is header-only, no library needed

    // Library: libevents_health_and_arming_checks
    const libevents_health_and_arming_checks = b.addStaticLibrary(.{
        .name = "libevents_health_and_arming_checks",
        .target = target,
        .optimize = optimize,
    });
    libevents_health_and_arming_checks.addIncludePath(upstream.path("libs/cpp"));
    libevents_health_and_arming_checks.linkLibCpp(); // Link C++ standard library
    libevents_health_and_arming_checks.addCSourceFiles(.{
        .files = &.{
            "parse/health_and_arming_checks.cpp",
        },
        .flags = &.{
            "-Wall",
            "-Wextra",
            "-Werror",
            "-Wconversion",
            "-Wpedantic",
            "-std=c++14",
        },
        .root = upstream.path("libs/cpp"),
    });
    b.installArtifact(libevents_health_and_arming_checks);

    // libevents_receive is header-only, no library needed

    // Main libevents interface library - create a simple wrapper
    const libevents = b.addStaticLibrary(.{
        .name = "libevents",
        .target = target,
        .optimize = optimize,
    });
    libevents.linkLibrary(libevents_parser);
    libevents.linkLibrary(libevents_health_and_arming_checks);
    libevents.addIncludePath(upstream.path("libs/cpp"));
    libevents.linkLibCpp(); // Link C++ standard library

    // Add a minimal empty source file to satisfy the linker
    libevents.addCSourceFiles(.{
        .files = &.{},
        .root = upstream.path("libs/cpp"),
    });

    // Create an empty C++ file inline to satisfy linker requirements
    const empty_cpp = b.addWriteFiles();
    const empty_file = empty_cpp.add("libevents_interface.cpp",
        \\// Empty interface file for libevents
        \\// This library is header-only and links other libraries
        \\
    );
    libevents.addCSourceFile(.{
        .file = empty_file,
        .flags = &.{"-std=c++14"},
    });

    b.installArtifact(libevents);

    libevents.installHeadersDirectory(upstream.path("libs/cpp/parse"), "libevents/parse", .{});
    libevents.installHeadersDirectory(upstream.path("libs/cpp/common"), "libevents/common", .{});
    libevents.installHeadersDirectory(upstream.path("libs/cpp/protocol"), "libevents/protocol", .{});

    // Tests
    if (main_project and enable_testing) {
        const tests = b.addTest(.{
            .root_source_file = upstream.path("libs/cpp/tests/test_main.zig"),
            .target = target,
            .optimize = optimize,
        });
        tests.linkLibrary(libevents);

        const run_tests = b.addRunArtifact(tests);
        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_tests.step);
    }

    // Format target
    const fmt = b.addSystemCommand(&.{
        "scripts/run_clang_format.sh",
        "clang-format",
    });
    fmt.cwd = upstream.path("libs/cpp");

    // Add source files to be formatted (using simple file arguments)
    fmt.addArg("parse/parser.cpp");
    fmt.addArg("parse/parser.h");
    fmt.addArg("parse/health_and_arming_checks.cpp");
    fmt.addArg("parse/health_and_arming_checks.h");
    fmt.addArg("protocol/receive.h");

    if (enable_testing) {
        fmt.addArg("tests/*.cpp");
        fmt.addArg("tests/*.h");
    }

    const fmt_step = b.step("format", "Format source files");
    fmt_step.dependOn(&fmt.step);
}
