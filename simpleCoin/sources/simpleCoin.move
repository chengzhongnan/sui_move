module simpleCoin::ADC {
    use std::option;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct ADC has drop {
    }

    fun init(witness: ADC, ctx: &mut TxContext) {

        let sender = tx_context::sender(ctx);

        let (treasuryCap, coinMetadata) = coin::create_currency(witness, 7u8, b"ADC", b"ADC", b"ADC Coin", option::none(), ctx);
        transfer::public_transfer(treasuryCap, sender);
        transfer::public_freeze_object(coinMetadata);
    }

    public entry fun mint(
        treasury_cap: &mut TreasuryCap<ADC>, amount: u64, recipient: address, ctx: &mut TxContext
    ) {
        coin::mint_and_transfer(treasury_cap, amount, recipient, ctx)
    }

    public entry fun burn(treasury_cap: &mut TreasuryCap<ADC>, coin: Coin<ADC>) {
        coin::burn(treasury_cap, coin);
    }

}