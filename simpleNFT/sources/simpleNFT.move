module simpleNFT::aida_NFT {
    use std::string::{Self, utf8};
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::display;
    use sui::package::{Self};

    /// An example NFT that can be minted by anybody
    struct AidaNFT has key, store {
        id: UID,
        /// Name for the token
        name: string::String,
        /// Description of the token
        description: string::String,
        /// URL for the token
        img_url: string::String,
    }

    // ===== Events =====

    struct NFTMinted has copy, drop {
        // The Object ID of the NFT
        object_id: ID,
        // The creator of the NFT
        creator: address,
        // The name of the NFT
        name: string::String,
    }

    struct AIDA_NFT has drop {}

    // ===== Public view functions =====
    fun init(otw: AIDA_NFT, ctx: &mut TxContext) {
        let keys = vector[
            utf8(b"name"),
            utf8(b"link"),
            utf8(b"image_url"),
            utf8(b"description"),
            utf8(b"project_url"),
            utf8(b"creator"),
        ];

        let values = vector[
            // For `name` one can use the `Hero.name` property
            utf8(b"{name}"),
            // For `link` one can build a URL using an `id` property
            utf8(b"https://aidameta.io/aida/{id}"),
            // For `image_url` we use an IPFS template + `img_url` property.
            utf8(b"{img_url}"),
            // Description is static for all `Hero` objects.
            utf8(b"a aidameta in sui chain"),
            // Project URL is usually static
            utf8(b"https://aidameta.io"),
            // Creator field can be any
            utf8(b"cheng")
        ];

        // Claim the `Publisher` for the package!
        let publisher = package::claim(otw, ctx);

        // Get a new `Display` object for the `Hero` type.
        let display = display::new_with_fields<AidaNFT>(
            &publisher, keys, values, ctx
        );

        // Commit first version of `Display` to apply changes.
        display::update_version(&mut display);

        let sender = tx_context::sender(ctx);

        transfer::public_transfer(publisher, sender);
        transfer::public_transfer(display, sender);
    }


    /// Get the NFT's `name`
    public fun name(nft: &AidaNFT): &string::String {
        &nft.name
    }

    /// Get the NFT's `description`
    public fun description(nft: &AidaNFT): &string::String {
        &nft.description
    }

    /// Get the NFT's `url`
    public fun url(nft: &AidaNFT): &string::String {
        &nft.img_url
    }

    public entry fun mint(
        name: string::String,
        description: string::String,
        url: string::String,
        ctx: &mut TxContext
    ) {
        let sender: address = tx_context::sender(ctx);
        let nft = AidaNFT {
            id: object::new(ctx),
            name: name,
            description: description,
            img_url: url
        };

        transfer::transfer(nft, sender);
    }

    /// Transfer `nft` to `recipient`
    public entry fun transfer(
        nft: AidaNFT, recipient: address, _: &mut TxContext
    ) {
        transfer::public_transfer(nft, recipient)
    }

    /// Update the `description` of `nft` to `new_description`
    public entry fun update_description(
        nft: &mut AidaNFT,
        new_description: vector<u8>,
        _: &mut TxContext
    ) {
        nft.description = string::utf8(new_description)
    }

    /// Permanently delete `nft`
    public entry fun burn(nft: AidaNFT, _: &mut TxContext) {
        let AidaNFT { id, name: _, description: _, img_url: _ } = nft;
        object::delete(id)
    }
}