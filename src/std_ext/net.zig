//! Networking Utilities for Game Engine Development
//!

const std = @import("std");

/// Simple TCP client
pub const TcpClient = struct {
    stream: ?std.net.Stream,
    address: std.net.Address,

    pub fn connect(host: []const u8, port: u16) !TcpClient {
        const address = try std.net.Address.parseIp4(host, port);
        const stream = try address.tcpConnect();
        return TcpClient{ .stream = stream, .address = address };
    }

    pub fn disconnect(self: *TcpClient) void {
        if (self.stream) |stream| {
            stream.close();
            self.stream = null;
        }
    }

    pub fn send(self: *TcpClient, data: []const u8) !usize {
        if (self.stream) |stream| {
            return stream.write(data);
        }
        return error.NotConnected;
    }

    pub fn receive(self: *TcpClient, buffer: []u8) !usize {
        if (self.stream) |stream| {
            return stream.read(buffer);
        }
        return error.NotConnected;
    }

    pub fn receiveAll(self: *TcpClient, buffer: []u8) !void {
        var total_read: usize = 0;
        while (total_read < buffer.len) {
            const bytes = try self.receive(buffer[total_read..]);
            if (bytes == 0) return error.ConnectionClosed;
            total_read += bytes;
        }
    }
};

/// Simple TCP server
pub const TcpServer = struct {
    listener: ?std.net.Server,
    address: std.net.Address,

    pub fn listen(port: u16, max_pending: usize) !TcpServer {
        const address = try std.net.Address.parseIp4("0.0.0.0", port);
        const listener = try address.listen(.{ .reuse_address = true, .max_pendingConnections = max_pending });
        return TcpServer{ .listener = listener, .address = address };
    }

    pub fn accept(self: *TcpServer) !TcpClient {
        if (self.listener) |listener| {
            const conn = try listener.accept();
            return TcpClient{ .stream = conn, .address = conn.address };
        }
        return error.NotListening;
    }

    pub fn close(self: *TcpServer) void {
        if (self.listener) |listener| {
            listener.close();
            self.listener = null;
        }
    }
};

/// Packet types for game protocol
pub const PacketType = enum(u8) {
    heartbeat = 0,
    player_state = 1,
    world_update = 2,
    chat = 3,
    input = 4,
    connect = 5,
    disconnect = 6,
};

/// Game packet structure
pub const GamePacket = struct {
    packet_type: PacketType,
    sequence: u16,
    timestamp: u64,
    payload: []u8,

    pub fn serialize(allocator: std.mem.Allocator, packet: GamePacket) ![]u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        errdefer buffer.deinit();

        try buffer.append(@intFromEnum(packet.packet_type));
        try buffer.writer().writeIntLittle(u16, packet.sequence);
        try buffer.writer().writeIntLittle(u64, packet.timestamp);
        try buffer.writer().writeIntLittle(u32, @intCast(packet.payload.len));
        try buffer.appendSlice(packet.payload);

        return buffer.toOwnedSlice();
    }

    pub fn deserialize(data: []const u8) !GamePacket {
        if (data.len < 13) return error.PacketTooShort;

        return GamePacket{
            .packet_type = @as(PacketType, @enumFromInt(data[0])),
            .sequence = std.mem.readIntLittle(u16, data[1..3]),
            .timestamp = std.mem.readIntLittle(u64, data[3..11]),
            .payload = @constCast(data[11..]),
        };
    }
};

/// UDP packet for fast unreliable communication
pub const UdpPacket = struct {
    data: []u8,

    pub fn send(self: *UdpPacket, stream: std.net.Stream) !void {
        const len_bytes = std.mem.asBytes(@as(u32, @intCast(self.data.len)));
        try stream.writeAll(len_bytes);
        try stream.writeAll(self.data);
    }

    pub fn receive(stream: std.net.Stream, allocator: std.mem.Allocator) !UdpPacket {
        var len_bytes: [4]u8 = undefined;
        _ = try stream.readAll(&len_bytes);
        const len = std.mem.readIntLittle(u32, &len_bytes);

        const data = try allocator.alloc(u8, len);
        errdefer allocator.free(data);

        try stream.readAll(data);
        return UdpPacket{ .data = data };
    }
};
