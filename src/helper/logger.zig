const std = @import("std");
const config = @import("config.zig");

pub fn info(comptime message: []const u8) void {
    if (!config.enable_inscpection) return;

    std.debug.print(message ++ "\n", .{});
}

pub fn infof(comptime message: []const u8, args: anytype) void {
    if (!config.enable_inscpection) return;

    std.debug.print(message ++ "\n", args);
}
