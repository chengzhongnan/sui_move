// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Module representing a common type for regulated coins. Features balance
/// accessors which can be used to implement a RegulatedCoin interface.
///
/// To implement any of the methods, module defining the type for the currency
/// is expected to implement the main set of methods such as `borrow()`,
/// `borrow_mut()` and `zero()`.
///
/// Each of the methods of this module requires a Witness struct to be sent.
module adec::regulated_coin {
    use sui::balance::{Self, Balance};
    use sui::tx_context::TxContext;
    use sui::object::{Self, UID};

    /// The RegulatedCoin struct; holds a common `Balance<T>` which is compatible
    /// with all the other Coins and methods, as well as the `creator` field, which
    /// can be used for additional security/regulation implementations.
    struct RegulatedCoin<phantom T> has key, store {
        id: UID,
        balance: Balance<T>,
        creator: address
    }

    /// Get the `RegulatedCoin.balance.value` field;
    public fun value<T>(c: &RegulatedCoin<T>): u64 {
        balance::value(&c.balance)
    }

    /// Get the `RegulatedCoin.creator` field;
    public fun creator<T>(c: &RegulatedCoin<T>): address {
        c.creator
    }

    // === Necessary set of Methods (provide security guarantees and balance access) ===

    /// Get an immutable reference to the Balance of a RegulatedCoin;
    public fun borrow<T: drop>(_: T, coin: &RegulatedCoin<T>): &Balance<T> {
        &coin.balance
    }

    /// Get a mutable reference to the Balance of a RegulatedCoin;
    public fun borrow_mut<T: drop>(_: T, coin: &mut RegulatedCoin<T>): &mut Balance<T> {
        &mut coin.balance
    }

    /// Author of the currency can restrict who is allowed to create new balances;
    public fun zero<T: drop>(_: T, creator: address, ctx: &mut TxContext): RegulatedCoin<T> {
        RegulatedCoin { id: object::new(ctx), balance: balance::zero(), creator }
    }

    /// Build a transferable `RegulatedCoin` from a `Balance`;
    public fun from_balance<T: drop>(
        _: T, balance: Balance<T>, creator: address, ctx: &mut TxContext
    ): RegulatedCoin<T> {
        RegulatedCoin { id: object::new(ctx), balance, creator }
    }

    /// Destroy `RegulatedCoin` and return its `Balance`;
    public fun into_balance<T: drop>(_: T, coin: RegulatedCoin<T>): Balance<T> {
        let RegulatedCoin { balance, creator: _, id } = coin;
        sui::object::delete(id);
        balance
    }

    // === Optional Methods (can be used for simpler implementation of basic operations) ===

    /// Join Balances of a `RegulatedCoin` c1 and `RegulatedCoin` c2.
    public fun join<T: drop>(witness: T, c1: &mut RegulatedCoin<T>, c2: RegulatedCoin<T>) {
        balance::join(&mut c1.balance, into_balance(witness, c2));
    }

    /// Subtract `RegulatedCoin` with `value` from `RegulatedCoin`.
    ///
    /// This method does not provide any checks by default and can possibly lead to mocking
    /// behavior of `Regulatedcoin::zero()` when a value is 0. So in case empty balances
    /// should not be allowed, this method should be additionally protected against zero value.
    public fun split<T: drop>(
        witness: T, c1: &mut RegulatedCoin<T>, creator: address, value: u64, ctx: &mut TxContext
    ): RegulatedCoin<T> {
        let balance = balance::split(&mut c1.balance, value);
        from_balance(witness, balance, creator, ctx)
    }
}

module adec::AdecCoin {
    use adec::regulated_coin::{Self as rcoin, RegulatedCoin as RCoin};
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Supply, Balance};
    use sui::object::{Self, UID};
    use sui::coin::{Self, Coin};
    use sui::transfer;
    use std::vector;

    /// The ticker of Abc regulated token
    struct ADEC has drop {}

    /// A restricted transfer of Abc to another account.
    struct Transfer has key {
        id: UID,
        balance: Balance<ADEC>,
        to: address,
    }

    /// A registry of addresses banned from using the coin.
    struct Registry has key {
        id: UID,
        banned: vector<address>,
        swapped_amount: u64,
    }

    /// A AbcTreasuryCap for the balance::Supply.
    struct ADECTreasuryCap has key, store {
        id: UID,
        supply: Supply<ADEC>
    }

    /// For when an attempting to interact with another account's RegulatedCoin<Abc>.
    const ENotOwner: u64 = 1;

    /// For when address has been banned and someone is trying to access the balance
    const EAddressBanned: u64 = 2;

    /// Create the Abc currency and send the AbcTreasuryCap to the creator
    /// as well as the first (and empty) balance of the RegulatedCoin<Abc>.
    ///
    /// Also creates a shared Registry which holds banned addresses.
    fun init(ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let treasury_cap = ADECTreasuryCap {
            id: object::new(ctx),
            supply: balance::create_supply(ADEC {})
        };

        transfer::public_transfer(zero(sender, ctx), sender);
        transfer::public_transfer(treasury_cap, sender);

        transfer::share_object(Registry {
            id: object::new(ctx),
            banned: vector::empty(),
            swapped_amount: 0,
        });
    }

    // === Getters section: Registry ===

    /// Get total amount of `Coin` from the `Registry`.
    public fun swapped_amount(r: &Registry): u64 {
        r.swapped_amount
    }

    /// Get vector of banned addresses from `Registry`.
    public fun banned(r: &Registry): &vector<address> {
        &r.banned
    }

    // === Admin actions: creating balances, minting coins and banning addresses ===

    /// Create an empty `RCoin<Abc>` instance for account `for`. AbcTreasuryCap is passed for
    /// authentication purposes - only admin can create new accounts.
    public entry fun create(_: &ADECTreasuryCap, for: address, ctx: &mut TxContext) {
        transfer::public_transfer(zero(for, ctx), for)
    }

    /// Mint more Abc. Requires AbcTreasuryCap for authorization, so can only be done by admins.
    public entry fun mint(treasury: &mut ADECTreasuryCap, owned: &mut RCoin<ADEC>, value: u64) {
        balance::join(borrow_mut(owned), balance::increase_supply(&mut treasury.supply, value));
    }

    /// Burn `value` amount of `RCoin<Abc>`. Requires AbcTreasuryCap for authorization, so can only be done by admins.
    ///
    /// TODO: Make AbcTreasuryCap a part of Balance module instead of Coin.
    public entry fun burn(treasury: &mut ADECTreasuryCap, owned: &mut RCoin<ADEC>, value: u64) {
        balance::decrease_supply(
            &mut treasury.supply,
            balance::split(borrow_mut(owned), value)
        );
    }

    /// Ban some address and forbid making any transactions from or to this address.
    /// Only owner of the AbcTreasuryCap can perform this action.
    public entry fun ban(_cap: &ADECTreasuryCap, registry: &mut Registry, to_ban: address) {
        vector::push_back(&mut registry.banned, to_ban)
    }

    // === Public: Regulated transfers ===

    /// Transfer entrypoint - create a restricted `Transfer` instance and transfer it to the
    /// `to` account for being accepted later.
    /// Fails if sender is not an creator of the `RegulatedCoin` or if any of the parties is in
    /// the ban list in Registry.
    public entry fun transfer(r: &Registry, coin: &mut RCoin<ADEC>, value: u64, to: address, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        assert!(rcoin::creator(coin) == sender, ENotOwner);
        assert!(vector::contains(&r.banned, &to) == false, EAddressBanned);
        assert!(vector::contains(&r.banned, &sender) == false, EAddressBanned);

        transfer::transfer(Transfer {
            to,
            id: object::new(ctx),
            balance: balance::split(borrow_mut(coin), value),
        }, to)
    }

    /// Accept an incoming transfer by joining an incoming balance with an owned one.
    ///
    /// Fails if:
    /// 1. the `RegulatedCoin<Abc>.creator` does not match `Transfer.to`;
    /// 2. the address of the creator/recipient is banned;
    public entry fun accept_transfer(r: &Registry, coin: &mut RCoin<ADEC>, transfer: Transfer) {
        let Transfer { id, balance, to } = transfer;

        assert!(rcoin::creator(coin) == to, ENotOwner);
        assert!(vector::contains(&r.banned, &to) == false, EAddressBanned);

        balance::join(borrow_mut(coin), balance);
        object::delete(id)
    }

    // === Public: Swap RegulatedCoin <-> Coin ===

    /// Take `value` amount of `RegulatedCoin` and make it freely transferable by wrapping it into
    /// a `Coin`. Update `Registry` to keep track of the swapped amount.
    ///
    /// Fails if:
    /// 1. `RegulatedCoin<Abc>.creator` was banned;
    /// 2. `RegulatedCoin<Abc>` is not owned by the tx sender;
    public entry fun take(r: &mut Registry, coin: &mut RCoin<ADEC>, value: u64, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        assert!(rcoin::creator(coin) == sender, ENotOwner);
        assert!(vector::contains(&r.banned, &sender) == false, EAddressBanned);

        // Update swapped amount for Registry to keep track of non-regulated amounts.
        r.swapped_amount = r.swapped_amount + value;

        transfer::public_transfer(coin::take(borrow_mut(coin), value, ctx), sender);
    }

    /// Take `Coin` and put to the `RegulatedCoin`'s balance.
    ///
    /// Fails if:
    /// 1. `RegulatedCoin<Abc>.creator` was banned;
    /// 2. `RegulatedCoin<Abc>` is not owned by the tx sender;
    public entry fun put_back(r: &mut Registry, rc_coin: &mut RCoin<ADEC>, coin: Coin<ADEC>, ctx: &TxContext) {
        let balance = coin::into_balance(coin);
        let sender = tx_context::sender(ctx);

        assert!(rcoin::creator(rc_coin) == sender, ENotOwner);
        assert!(vector::contains(&r.banned, &sender) == false, EAddressBanned);

        // Update swapped amount as in `swap_regulated`.
        r.swapped_amount = r.swapped_amount - balance::value(&balance);

        balance::join(borrow_mut(rc_coin), balance);
    }

    // === Private implementations accessors and type morphing ===

    fun borrow(coin: &RCoin<ADEC>): &Balance<ADEC> { rcoin::borrow(ADEC {}, coin) }
    fun borrow_mut(coin: &mut RCoin<ADEC>): &mut Balance<ADEC> { rcoin::borrow_mut(ADEC {}, coin) }
    fun zero(creator: address, ctx: &mut TxContext): RCoin<ADEC> { rcoin::zero(ADEC {}, creator, ctx) }

    fun into_balance(coin: RCoin<ADEC>): Balance<ADEC> { rcoin::into_balance(ADEC {}, coin) }
    fun from_balance(balance: Balance<ADEC>, creator: address, ctx: &mut TxContext): RCoin<ADEC> {
        rcoin::from_balance(ADEC {}, balance, creator, ctx)
    }
}