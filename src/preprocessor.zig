const std = @import("std");
const c = @cImport({
    @cInclude("expat.h");
});

const UserData = struct {
    stdout: std.io.AnyWriter,
    num_nodes: u64 = 0,
};

fn start_element(ctx: ?*anyopaque, name_c: [*c]const c.XML_Char, attrs: [*c][*c]const c.XML_Char) callconv(.C) void {
    const user_data: *UserData = @ptrCast(@alignCast(ctx));

    const name = std.mem.span(name_c);
    if (!std.mem.eql(u8, name, "node")) {
        return;
    }

    var i: usize = 0;
    var lat_opt: ?[]const u8 = null;
    var lon_opt: ?[]const u8 = null;
    while (true) {
        defer i += 2;

        if (attrs[i] == null) {
            break;
        }
        const field_name = std.mem.span(attrs[i]);
        const field_val = std.mem.span(attrs[i + 1]);

        if (std.mem.eql(u8, field_name, "lat_opt")) {
            lat_opt = field_val;
        } else if (std.mem.eql(u8, field_name, "lon_opt")) {
            lon_opt = field_val;
        }
    }

    const lat_s = lat_opt orelse return;
    const lon_s = lon_opt orelse return;

    const lat = std.fmt.parseFloat(f32, lat_s) catch return;
    const lon = std.fmt.parseFloat(f32, lon_s) catch return;

    user_data.stdout.print(
        \\ .{{
        \\ .lat = {d},
        \\ .lon = {d},
        \\}}
    , .{ lat, lon }) catch return;

    if (std.mem.eql(u8, name, "node")) {
        user_data.num_nodes += 1;
    }
}

pub fn main() !void {
    const parser = c.XML_ParserCreate(null);
    defer c.XML_ParserFree(parser);

    var stdout_buf_writer = std.io.bufferedWriter(std.io.getStdOut().writer().any());
    defer stdout_buf_writer.flush() catch unreachable;
    const stdout_writer = stdout_buf_writer.writer().any();

    try stdout_writer.writeAll(
        \\ const Point = struct {
        \\  lat: f32,
        \\  lon: f32,
        \\   };
        \\ cont points = [_]Point{
    );
    defer stdout_writer.writeAll(
        \\
        \\ };
        \\
    ) catch unreachable;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();
    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    const f = try std.fs.cwd().openFile(args[1], .{});
    defer f.close();
    var buffered_reader = std.io.bufferedReader(f.reader());

    if (parser == null) {
        return error.NoParser;
    }
    var userdata = UserData{
        .stdout = stdout_writer,
    };
    c.XML_SetUserData(parser, &userdata);
    c.XML_SetElementHandler(parser, start_element, null);

    var i: u64 = 0;
    while (true) {
        i += 1;
        if (i % 1000 == 0) {
            std.debug.print("{d}\n", .{userdata.num_nodes});
        }
        if (i == 1000) {
            break;
        }
        const buf_size = 4096;
        const buf = c.XML_GetBuffer(parser, buf_size);
        if (buf == null) {
            return error.NoBuffer;
        }

        const buf_u8: [*]u8 = @ptrCast(buf);
        const buf_slice = buf_u8[0..buf_size];
        const read_data_len = try buffered_reader.read(buf_slice);
        if (read_data_len == 0) {
            break;
        }

        const parse_ret = c.XML_ParseBuffer(parser, @intCast(read_data_len), 0);

        if (parse_ret == c.XML_STATUS_ERROR) {
            return error.ParseError;
        }
    }
}
