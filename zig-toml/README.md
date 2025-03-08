# zig-toml

Zig [TOML v1.0.0](https://toml.io/en/v1.0.0) parser.

This is a top-down LL parser that parses directly into Zig structs.

## Features
* TOML Syntax
  * [x] Integers, hexadecimal, octal, and binary numbers
  * [x] Floats
  * [x] Booleans
  * [x] Comments
  * [x] Arrays
  * [x] Tables
  * [x] Array of Tables
  * [x] Inline Table
  * [x] Single-line strings
  * [x] String escapes (also unicode)
  * [x] Multi-line strings
  * [x] Multi-line string leading space trimming
  * [x] Trailing backslash in multi-line strings
  * [x] Date, time, date-time, time offset
* Struct mapping
  * [x] Mapping to structs
  * [x] Mapping to enums
  * [x] Mapping to slices
  * [x] Mapping to arrays
  * [x] Mapping to pointers
  * [x] Mapping to integer and floats with lower bit number than defined by TOML, i.e. `i16`, `f32`.
  * [x] Mapping to optional fields
  * [x] Mapping to HashMaps
* [ ] Serialization
    * [x] Basic types like integers, floating points, strings, booleans etc.
    * [x] Arrays
    * [x] Top level tables
    * [x] Sub tables
    * [x] Pointers
    * [x] Date, time, DateTime, time offset
    * [x] Enums
    * [x] Unions

## Using with the Zig package manager
Add `zig-toml` to your `build.zig.zon`
```
# For zig-master
zig fetch --save git+https://github.com/sam701/zig-toml

# For zig 0.13
zig fetch --save git+https://github.com/sam701/zig-toml#last-zig-0.13
```

## Example
See [`example1.zig`](./examples/example1.zig) for the complete code that parses [`example.toml`](./examples/example1.toml)

Run it with `zig build examples`
```zig
// .... 

const Address = struct {
    port: i64,
    host: []const u8,
};

const Config = struct {
    master: bool,
    expires_at: toml.DateTime,
    description: []const u8,

    local: *Address,
    peers: []const Address,
};

pub fn main() anyerror!void {
    var parser = toml.Parser(Config).init(allocator);
    defer parser.deinit();

    var result = try parser.parseFile("./examples/example1.toml");
    defer result.deinit();

    const config = result.value;
    std.debug.print("{s}\nlocal address: {s}:{}\n", .{ config.description, config.local.host, config.local.port });
    std.debug.print("peer0: {s}:{}\n", .{ config.peers[0].host, config.peers[0].port });
}
```

## Error Handling
TODO

## License
MIT
