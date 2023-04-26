module basics::clock {
    use sui::clock::{Self, Clock};
    use sui::event;
    use sui::tx_context::TxContext;

    struct TimeEvent has copy, drop {
        timestamp_ms: u64,
    }

    /// Emit event with current time.
    public entry fun get_time(clock: &Clock, _ctx: &mut TxContext) {
        event::emit(TimeEvent { timestamp_ms: clock::timestamp_ms(clock) });
    }
}