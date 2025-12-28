const std = @import("std");
pub fn main() void {
    const S = std.json.Stringify;
    inline for (@typeInfo(S).@"struct".decls) |decl| {
        std.debug.print("{s}\n", .{decl.name});
    }
}
