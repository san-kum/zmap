const std = @import("std");

pub const RenderMode = enum {
    POINTS,
    LINE_STRIP,
    TRIANGLE_STRIP,
};

pub extern fn compileLinkProgram(vs: [*]const u8, vs_len: usize, fs: [*]const u8, fs_len: usize) i32;
pub extern fn bind2DFloatData(data: [*]const f32, data_len: usize) i32;
pub extern fn glBindVertexArray(vao: i32) void;
pub extern fn glClearColor(r: f32, g: f32, b: f32, a: f32) void;
pub extern fn glClear(mask: i32) void;
pub extern fn glUseProgram(program: i32) void;
pub extern fn glDrawArrays(mode: i32, first: i32, last: i32) void;

const COLOR_BUFFER_BIT = 16384;

fn getRenderModeValue(mode: RenderMode) i32 {
    return switch (mode) {
        .POINTS => 0,
        .LINE_STRIP => 3,
        .TRIANGLE_STRIP => 5,
    };
}

pub export fn run() void {
    const vs_source =
        \\attribute vec4 aVertexPosition;
        \\void main() {
        \\gl_Position = aVertexPosition;
        \\gl_PointSize = 10.0;
        \\}
    ;

    const fs_source =
        \\void main() {
        \\gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0);
        \\}
    ;

    const positions: []const f32 = &.{ 0.5, 0.5, -0.5, 0.5, 0.5, -0.5, -0.5, -0.5 };
    const program = compileLinkProgram(vs_source, vs_source.len, fs_source, fs_source.len);
    const vao = bind2DFloatData(positions.ptr, positions.len);
    glBindVertexArray(vao);
    glClearColor(1.0, 1.0, 0.0, 1.0);
    glClear(COLOR_BUFFER_BIT);

    glUseProgram(program);
    {
        const offset = 0;
        const vertexCount = 4;
        const renderMode = getRenderModeValue(.POINTS);
        glDrawArrays(renderMode, offset, vertexCount);
    }
}
