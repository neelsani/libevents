# libevents Zig Build Integration

Zig build system integration for [libevents](https://github.com/mavlink/libevents) 

## Quick Start

1. Add to your project:
```bash
zig fetch --save git+https://github.com/neelsani/libevents
```
2. Add to your build.zig

```zig
const libevents_dep = b.dependency("libevents", .{
    .target = target,
    .optimize = optimize,
});
const lib = libevents_dep.artifact("libevents");

//then link it to your exe

exe.linkLibrary(lib);
```