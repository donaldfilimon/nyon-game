//! ECS Query system for iterating entities with specific components

const std = @import("std");
const Entity = @import("entity.zig").Entity;
const World = @import("world.zig").World;
const component = @import("component.zig");

/// Query builder for iterating entities with specific components
pub fn Query(comptime Components: []const type) type {
    return struct {
        world: *World,

        const Self = @This();

        pub fn init(world: *World) Self {
            return .{ .world = world };
        }

        /// Iterator for query results
        pub const Iterator = struct {
            world: *World,
            index: usize,
            entities: []const Entity,

            pub fn next(self: *Iterator) ?QueryResult(Components) {
                while (self.index < self.entities.len) {
                    const entity = self.entities[self.index];
                    self.index += 1;

                    if (self.world.isAlive(entity)) {
                        var result: QueryResult(Components) = undefined;
                        result.entity = entity;

                        var all_present = true;
                        inline for (Components, 0..) |T, i| {
                            if (self.world.getComponent(entity, T)) |comp| {
                                result.components[i] = comp;
                            } else {
                                all_present = false;
                                break;
                            }
                        }

                        if (all_present) return result;
                    }
                }
                return null;
            }
        };

        pub fn iter(self: *Self) Iterator {
            // Use the first component's entity list
            const first_storage = self.world.getStorage(Components[0]);
            return Iterator{
                .world = self.world,
                .index = 0,
                .entities = first_storage.entities.items,
            };
        }
    };
}

fn QueryResult(comptime Components: []const type) type {
    return struct {
        entity: Entity,
        components: [Components.len]*anyopaque,

        pub fn get(self: *@This(), comptime T: type) *T {
            inline for (Components, 0..) |C, i| {
                if (C == T) {
                    return @ptrCast(@alignCast(self.components[i]));
                }
            }
            @compileError("Component not in query");
        }
    };
}

/// Convenience functions for common queries
pub fn queryWith(world: *World, comptime T: type) Query(&[_]type{T}) {
    return Query(&[_]type{T}).init(world);
}

pub fn queryWith2(world: *World, comptime T1: type, comptime T2: type) Query(&[_]type{ T1, T2 }) {
    return Query(&[_]type{ T1, T2 }).init(world);
}
