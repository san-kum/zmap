const std = @import("std");
const c = @cImport({
    @cInclude("expat.h");
});

const UserData = struct {
    num_nodes: u64 = 0,
};
fn start_element(ctx: ?*anyopaque, name_c: [*c]const c.XML_Char, attrs: [*c][*c]const c.XML_Char) callconv(.C) void {
    const user_data: *UserData = @ptrCast(@alignCast(ctx));
    _ = attrs;

    const name = std.mem.span(name_c);
    if (std.mem.eql(u8, name, "node")) {
        user_data.num_nodes += 1;
    }
}

pub fn main() !void {
    const parser = c.XML_ParserCreate(null);
    defer c.XML_ParserFree(parser);

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
    var userdata = UserData{};
    c.XML_SetUserData(parser, &userdata);
    c.XML_SetElementHandler(parser, start_element, null);

    var i: u64 = 0;
    while (true) {
        i += 1;
        if (i % 1000 == 0) {
            std.debug.print("{any}\n", .{userdata});
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
