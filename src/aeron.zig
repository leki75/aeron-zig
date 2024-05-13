const std = @import("std");
// const aeronC = @cImport({
//     @cInclude("aeronc.h");
// });

const aeronC = struct {
    const aeron_frame_header_t = extern struct {
        frame_length: i32,
        version: i8,
        flags: u8,
        type: i16,
    };

    const aeron_data_header_t = extern struct {
        frame_header: aeron_frame_header_t,
        term_offset: i32,
        session_id: i32,
        stream_id: i32,
        term_id: i32,
        reserved_value: i64,
    };

    const aeron_header_t = extern struct {
        frame: *aeron_data_header_t,
        initial_term_id: i32,
        position_bits_to_shift: usize,
    };

    const aeron_buffer_claim_t = extern struct {
        frame_header: *u8,
        data: [*]u8,
        length: usize,
    };

    const AERON_PUBLICATION_NOT_CONNECTED: i64 = -1;
    const AERON_PUBLICATION_BACK_PRESSURED: i64 = -2;
    const AERON_PUBLICATION_ADMIN_ACTION: i64 = -3;
    const AERON_PUBLICATION_CLOSED: i64 = -4;
    const AERON_PUBLICATION_MAX_POSITION_EXCEEDED: i64 = -5;
    const AERON_PUBLICATION_ERROR: i64 = -6;

    // error message
    extern fn aeron_errmsg() [*:0]const u8;

    // context
    const aeron_context_t = opaque {};
    extern fn aeron_context_init(*?*aeron_context_t) c_int;
    extern fn aeron_context_set_dir(*aeron_context_t, [*:0]const u8) c_int;
    extern fn aeron_context_set_client_name(*aeron_context_t, [*:0]const u8) c_int;
    extern fn aeron_context_close(*aeron_context_t) c_int;

    // aeron
    const aeron_t = opaque {};
    extern fn aeron_init(*?*aeron_t, *aeron_context_t) c_int;
    extern fn aeron_start(*aeron_t) c_int;
    extern fn aeron_close(*aeron_t) c_int;

    // subscription
    const aeron_subscription_t = opaque {};
    const aeron_async_add_subscription_t = opaque {};
    extern fn aeron_async_add_subscription(*?*aeron_async_add_subscription_t, *aeron_t, [*:0]const u8, i32, ?*anyopaque, ?*anyopaque, ?*anyopaque, ?*anyopaque) c_int;
    extern fn aeron_async_add_subscription_poll(*?*aeron_subscription_t, ?*aeron_async_add_subscription_t) c_int;
    extern fn aeron_subscription_poll(*aeron_subscription_t, aeron_fragment_handler_t, ?*anyopaque, usize) c_int;
    extern fn aeron_subscription_close(*aeron_subscription_t, ?*anyopaque, ?*anyopaque) c_int;
    const aeron_fragment_handler_t = *const fn (?*anyopaque, [*]const u8, usize, *aeron_header_t) callconv(.C) void;

    // publication
    const aeron_async_add_exclusive_publication_t = opaque {};
    const aeron_exclusive_publication_t = opaque {};
    extern fn aeron_async_add_exclusive_publication(*?*aeron_async_add_exclusive_publication_t, *aeron_t, [*:0]const u8, i32) c_int;
    extern fn aeron_async_add_exclusive_publication_poll(*?*aeron_exclusive_publication_t, ?*aeron_async_add_exclusive_publication_t) c_int;
    extern fn aeron_exclusive_publication_close(*aeron_exclusive_publication_t, ?*anyopaque, ?*anyopaque) c_int;
    extern fn aeron_exclusive_publication_try_claim(*aeron_exclusive_publication_t, usize, *aeron_buffer_claim_t) i64;
    extern fn aeron_buffer_claim_commit(buffer_claim: *aeron_buffer_claim_t) c_int;
    extern fn aeron_buffer_claim_abort(buffer_claim: *aeron_buffer_claim_t) c_int;
};

pub const FragmentHandler = aeronC.aeron_fragment_handler_t;
pub const Header = aeronC.aeron_header_t;
pub const DataHeader = aeronC.aeron_data_header_t;

pub const PUBLICATION_NOT_CONNECTED = aeronC.AERON_PUBLICATION_NOT_CONNECTED;
pub const PUBLICATION_BACK_PRESSURED = aeronC.AERON_PUBLICATION_BACK_PRESSURED;
pub const PUBLICATION_ADMIN_ACTION = aeronC.AERON_PUBLICATION_ADMIN_ACTION;
pub const PUBLICATION_CLOSED = aeronC.AERON_PUBLICATION_CLOSED;
pub const PUBLICATION_MAX_POSITION_EXCEEDED = aeronC.AERON_PUBLICATION_MAX_POSITION_EXCEEDED;
pub const PUBLICATION_ERROR = aeronC.AERON_PUBLICATION_ERROR;

fn err(e: c_int) !void {
    if (e < 0) {
        return error.AeronError;
    }
}

pub fn errMsg() [*:0]const u8 {
    return aeronC.aeron_errmsg();
}

pub const Context = struct {
    ctx: *aeronC.aeron_context_t,

    pub fn init() !Context {
        var ctx: ?*aeronC.aeron_context_t = undefined;
        try err(aeronC.aeron_context_init(&ctx));
        return Context{ .ctx = ctx.? };
    }

    pub fn setDir(self: Context, dir: [*:0]const u8) !void {
        return err(aeronC.aeron_context_set_dir(self.ctx, dir));
    }

    pub fn setClientName(self: Context, client_name: [*:0]const u8) !void {
        return err(aeronC.aeron_context_set_client_name(self.ctx, client_name));
    }

    pub fn deinit(self: Context) !void {
        return err(aeronC.aeron_context_close(self.ctx));
    }
};

pub const Aeron = struct {
    client: *aeronC.aeron_t,

    pub fn init(ctx: Context) !Aeron {
        var client: ?*aeronC.aeron_t = undefined;
        try err(aeronC.aeron_init(&client, ctx.ctx));
        return Aeron{ .client = client.? };
    }

    pub fn start(self: Aeron) !void {
        return err(aeronC.aeron_start(self.client));
    }

    pub fn addSubscription(self: Aeron, uri: [*:0]const u8, stream_id: i32) !Subscription {
        var as: ?*aeronC.aeron_async_add_subscription_t = undefined;
        try err(aeronC.aeron_async_add_subscription(&as, self.client, uri, stream_id, null, null, null, null));

        var subscription: ?*aeronC.aeron_subscription_t = null;
        while (subscription == null) {
            try err(aeronC.aeron_async_add_subscription_poll(&subscription, as));
            if (std.os.linux.sched_yield() < 0) return error.AeronError;
        }
        return Subscription{ .subscription = subscription.? };
    }

    pub fn addExclusivePublication(self: Aeron, uri: [*:0]const u8, stream_id: i32) !ExclusivePublication {
        var ap: ?*aeronC.aeron_async_add_exclusive_publication_t = undefined;
        try err(aeronC.aeron_async_add_exclusive_publication(&ap, self.client, uri, stream_id));

        var publication: ?*aeronC.aeron_exclusive_publication_t = null;
        while (publication == null) {
            try err(aeronC.aeron_async_add_exclusive_publication_poll(&publication, ap));
            if (std.os.linux.sched_yield() < 0) return error.AeronError;
        }
        return ExclusivePublication{ .publication = publication.? };
    }

    pub fn deinit(self: Aeron) !void {
        return err(aeronC.aeron_close(self.client));
    }
};

pub const Subscription = struct {
    subscription: *aeronC.aeron_subscription_t,

    pub fn poll(self: Subscription, handler: FragmentHandler, clientd: ?*anyopaque, limit: usize) i32 {
        return aeronC.aeron_subscription_poll(self.subscription, handler, clientd, limit);
    }

    pub fn deinit(self: Subscription) !void {
        return err(aeronC.aeron_subscription_close(self.subscription, null, null));
    }
};

pub const ExclusivePublication = struct {
    publication: *aeronC.aeron_exclusive_publication_t,

    pub fn tryClaim(self: ExclusivePublication, length: usize, claim: *BufferClaim) i64 {
        return aeronC.aeron_exclusive_publication_try_claim(self.publication, length, &claim.claim);
    }

    pub fn deinit(self: ExclusivePublication) !void {
        return err(aeronC.aeron_exclusive_publication_close(self.publication, null, null));
    }
};

pub const BufferClaim = struct {
    claim: aeronC.aeron_buffer_claim_t,

    pub fn commit(self: *BufferClaim) !void {
        return err(aeronC.aeron_buffer_claim_commit(&self.claim));
    }

    pub fn abort(self: *BufferClaim) !void {
        return err(aeronC.aeron_buffer_claim_abort(&self.claim));
    }
};
