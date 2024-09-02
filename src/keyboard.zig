pub const Keyboard = struct {
    keys: [16]bool,

    pub fn init() Keyboard {
        return Keyboard{
            .keys = [_]bool{false} ** 16,
        };
    }

    pub fn get_pressed(self: *const Keyboard) ?u8 {
        for (self.keys, 0..) |key, i| {
            if (key) {
                return @intCast(i);
            }
        }
        return null;
    }
};
