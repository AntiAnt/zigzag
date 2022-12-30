const std = @import("std");
const Api = @import("api.zig");
const ApiTypes = @import("api_modules.zig");

const RndGen = std.rand.DefaultPrng;

const Object = struct { x: f32 = 0, y: f32 = 0 };

const NUM_OBJECTS = 5000;

fn makeObject() Object {
    return Object{ .x = 0.0, .y = 0.0 };
}

pub const Game = struct {
    x: f32 = 30.0,
    y: f32 = 30.0,
    sprite: u32 = 2,
    map_offset: u32 = 0,
    rnd: std.rand.DefaultPrng,
    randomize_count: u32 = 0,
    random_seed: u32 = 0,
    objects: [NUM_OBJECTS]Object,

    pub fn init(api: *Api.Api) Game {
        var rnd = RndGen.init(0);

        // Build a map of grass.
        var x: u32 = 0;
        var y: u32 = 0;
        while (x < 256) {
            while (y < 256) {
                if (rnd.random().int(u8) % 10 == 0) {
                    api.mset(x, y, 1, 0);
                } else {
                    api.mset(x, y, 48, 0);
                }

                y += 1;
            }
            x += 1;
            y = 0;
        }

        var objects = [_]Object{makeObject()} ** NUM_OBJECTS;

        for (objects) |*o| {
            // Only place x and y on
            while (true) {
                var o_x = rnd.random().int(u32) % 100;
                var o_y = rnd.random().int(u32) % 100;
                if (api.mget(o_x, o_y, 0) == 48) {
                    o.*.x = @intToFloat(f32, o_x) * 8.0 + 0.1;
                    o.*.y = @intToFloat(f32, o_y) * 8.0 + 0.1;
                    break;
                }
            }
        }

        return .{ .rnd = rnd, .objects = objects };
    }

    pub fn walkableTile(self: Game, api: *Api.Api, x: f32, y: f32) bool {
        _ = self;
        if (x < 0 or x >= 256 * 8 or y < 0 or y > 256 * 8) {
            return false;
        }
        const tx = @floatToInt(u32, std.math.floor(x / 8.0));
        const ty = @floatToInt(u32, std.math.floor(y / 8.0));

        const tile = api.mget(tx, ty, 0); // == 48; // only grass is walkable.

        return tile == 48;
    }

    pub fn worldMove(self: Game, api: *Api.Api, x: f32, y: f32, w: f32, h: f32, dx: *f32, dy: *f32) void {
        // Keep world moving, ta
        self.worldMovePoint(api, x, y, dx, dy);
        self.worldMovePoint(api, x + w, y, dx, dy);
        self.worldMovePoint(api, x, y + h, dx, dy);
        self.worldMovePoint(api, x + w, y + h, dx, dy);
    }

    pub fn worldMovePoint(self: Game, api: *Api.Api, x: f32, y: f32, dx: *f32, dy: *f32) void {
        // Right now we want to see if we can move a single point.
        // We will separate moves into first left and right and then up and down.

        // First attempt to left and right.
        if (dx.* > 0.0 and !self.walkableTile(api, x + dx.*, y)) {
            dx.* = 0.0;
        }
        if (dx.* < 0.0 and !self.walkableTile(api, x + dx.*, y)) {
            dx.* = 0.0;
        }

        // Now update and move right and left.
        if (dy.* > 0.0 and !self.walkableTile(api, x + dx.*, y + dy.*)) {
            dy.* = 0.0;
        }
        if (dy.* < 0.0 and !self.walkableTile(api, x + dx.*, y + dy.*)) {
            dy.* = 0.0;
        }

        // Detect against any objects.
    }

    pub fn update(self: *Game, api: *Api.Api) void {
        var dx: f32 = 0;
        var dy: f32 = 0;

        if (api.btn(ApiTypes.Button.RIGHT)) {
            dx = 1.0;
        }
        if (api.btn(ApiTypes.Button.LEFT)) {
            dx = -1.0;
        }
        if (api.btn(ApiTypes.Button.DOWN)) {
            dy = 1.0;
        }
        if (api.btn(ApiTypes.Button.UP)) {
            dy = -1.0;
        }
        if (api.btnp(ApiTypes.Button.A)) {
            self.sprite = (self.sprite + 1) % 16;
        }

        // Our game objects are really 7x7 so they can fit into the cracks of the tile.
        self.worldMove(api, self.x, self.y, 7.0, 7.0, &dx, &dy);

        self.x += dx;
        self.y += dy;

        for (self.objects) |*o| {
            var o_dx = (self.rnd.random().float(f32) - 0.5) * 4.0;
            var o_dy = (self.rnd.random().float(f32) - 0.5) * 4.0;
            self.worldMove(api, o.*.x, o.*.y, 7.0, 7.0, &o_dx, &o_dy);
            o.*.x += o_dx;
            o.*.y += o_dy;
        }

        self.randomize_count = (self.randomize_count + 1) % 20;

        // Randomize.

        //if (self.randomize_count == 0) {
        //    self.random_seed = (self.random_seed + 1) % 3;
        //    var rnd = RndGen.init(self.random_seed);

        //    var x: u32 = 0;
        //    var y: u32 = 0;
        //    while (x < 256) {
        //        while (y < 256) {
        //            if (rnd.random().int(u8) % 10 == 0) {
        //                api.mset(x, y, 38 + rnd.random().int(u8) % 4, 1);
        //            } else {
        //                api.mset(x, y, 0, 1);
        //            }
        //            y += 1;
        //        }
        //        x += 1;
        //        y = 0;
        //    }
        //}

        api.camera(self.x - 64 - 4, self.y - 64 - 4);
    }

    pub fn draw(self: *Game, api: *Api.Api) void {
        // draw the map
        api.map(0, 0, 0, 0, 256, 256, 0);

        for (self.objects) |o| {
            api.spr(4, o.x, o.y, 8.0, 8.0);
        }
        api.spr(self.sprite, self.x, self.y, 8.0, 8.0);

        //api.map(0, 0, 0, 0, 256, 256, 1);
    }
};
