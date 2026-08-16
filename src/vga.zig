const std = @import("std");

const VGA_WIDTH = 80;
const VGA_HEIGHT = 25;
const VGA_BUFFER: u32 = 0xB8000;
const SERIAL_PORT: u16 = 0x3F8;

pub const Color = enum(u4) {
    black = 0,
    blue = 1,
    green = 2,
    cyan = 3,
    red = 4,
    magenta = 5,
    brown = 6,
    light_grey = 7,
    dark_grey = 8,
    light_blue = 9,
    light_green = 10,
    light_cyan = 11,
    light_red = 12,
    light_magenta = 13,
    yellow = 14,
    white = 15,
};

var cursor_row: usize = 0;
var cursor_col: usize = 0;

fn outb(port: u16, val: u8) void {
    asm volatile ("outb %%al, %%dx"
        :
        : [val] "{al}" (val),
          [port] "{dx}" (port),
    );
}

fn inb(port: u16) u8 {
    return asm volatile ("inb %%dx, %%al"
        : [result] "={al}" (-> u8),
        : [port] "{dx}" (port),
    );
}

fn serial_write(ch: u8) void {
    while ((inb(SERIAL_PORT + 5) & 0x20) == 0) {}
    outb(SERIAL_PORT, ch);
}

pub fn serial_init() void {
    outb(SERIAL_PORT + 1, 0x00);
    outb(SERIAL_PORT + 3, 0x80);
    outb(SERIAL_PORT + 0, 0x03);
    outb(SERIAL_PORT + 1, 0x00);
    outb(SERIAL_PORT + 3, 0x03);
    outb(SERIAL_PORT + 2, 0xC7);
    outb(SERIAL_PORT + 4, 0x0B);
}

fn vgaEntry(char: u8, fg: Color, bg: Color) u16 {
    const color: u8 = @as(u8, @intFromEnum(bg)) << 4 | @intFromEnum(fg);
    return @as(u16, color) << 8 | char;
}

fn write_char(ch: u8) void {
    serial_write(ch);
    if (ch == '\n') {
        cursor_col = 0;
        cursor_row += 1;
        if (cursor_row >= VGA_HEIGHT) cursor_row = 0;
        return;
    }
    const vga: [*]volatile u16 = @ptrFromInt(VGA_BUFFER);
    vga[(cursor_row * VGA_WIDTH) + cursor_col] = vgaEntry(ch, .light_grey, .black);
    cursor_col += 1;
    if (cursor_col >= VGA_WIDTH) {
        cursor_col = 0;
        cursor_row += 1;
        if (cursor_row >= VGA_HEIGHT) cursor_row = 0;
    }
}

pub fn write(msg: []const u8, row: usize, col: usize, fg: Color, bg: Color) void {
    const vga: [*]volatile u16 = @ptrFromInt(VGA_BUFFER);
    for (msg, 0..) |byte, i| {
        vga[(row * VGA_WIDTH) + col + i] = vgaEntry(byte, fg, bg);
    }
}

pub fn print_fmt(comptime fmt: []const u8, args: anytype) void {
    var buf: [256]u8 = undefined;
    if (std.fmt.bufPrint(&buf, fmt, args)) |msg| {
        for (msg) |ch| {
            write_char(ch);
        }
    } else |_| {}
}

pub fn clear() void {
    const vga: [*]volatile u16 = @ptrFromInt(VGA_BUFFER);
    for (0..VGA_WIDTH * VGA_HEIGHT) |i| {
        vga[i] = vgaEntry(' ', .light_grey, .black);
    }
    cursor_row = 0;
    cursor_col = 0;
}
