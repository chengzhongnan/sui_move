module crystalBall::aida {
    use sui::object::{Self, ID, UID};
    // use sui::event;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};
    use std::string::{String, utf8};
    // use std::option;
    use sui::package;
    use sui::display;
    use std::vector;
    use sui::clock::{Self, Clock};
    use sui::coin::{Coin};
    use sui::sui::SUI;

    struct GlobalData has key, store {
        id: UID,
        // record all aida key
        aidaKey: vector<ID>,
        creator: address,
        // record all aida key by user address, it will changed when aida transcation
        userNFT: Table<address, vector<ID>>,
        lastSeed: u64,
        owner: address,
        publisher: vector<address>,
        mintFee: u64
    }

    // meta data for aida
    struct Meta has store, drop {
        id: u64,
        url: String,
        name: String,
        description: String,
        publish: u64,
        tag: String,
        path: String
    }

    struct CrystalBall has key, store {
        id: UID,
        gene: String,
        birthday: u64,
        metadata: Table<u64, Meta>,
        name: String,
        description: String,
        image_url: String,
        creator: String,
        link: String,
        project_url: String,
        level: u64,
    }


    struct GetUserAidaEvent has copy, drop {
        result: vector<ID>,
        count: u64,
        nextIdx: u64
    }

    struct AIDA has drop {}

    fun init(otw: AIDA, ctx: &mut TxContext) {
        initNFT(otw, ctx);
        initGlobal(ctx);
    }

    fun initNFT(otw: AIDA, ctx: &mut TxContext) {
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
            utf8(b"{image_url}"),
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
        let display = display::new_with_fields<CrystalBall>(
            &publisher, keys, values, ctx
        );

        // Commit first version of `Display` to apply changes.
        display::update_version(&mut display);

        let sender = tx_context::sender(ctx);

        transfer::public_transfer(publisher, sender);
        transfer::public_transfer(display, sender);
    }

    fun initGlobal(ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        let gd = GlobalData {
            id: object::new(ctx),
            aidaKey: vector::empty<ID>(),
            creator: sender,
            userNFT: table::new(ctx),
            lastSeed: 1,
            owner: sender,
            publisher: vector::empty<address>()
        };

        transfer::public_share_object(gd);
    }

    public entry fun create_crystal_ball(clock: &Clock, gd: &mut GlobalData, owner: address, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        if (gd.owner == sender || vector::contains(&gd.publisher, &sender)) {
            let uid = object::new(ctx);
            let id = object::uid_to_inner(&uid);
            let timestamp_ms = clock::timestamp_ms(clock);
            let (gene, newSeed) = generate_random_gene(gd.lastSeed, timestamp_ms);
            
            let imageUrl: vector<u8> = b"https://image.aidameta.io/aida/";
            vector::append(&mut imageUrl, gene);
            vector::append(&mut imageUrl, b".png");
            gd.lastSeed = newSeed;

            let cb = CrystalBall {
                id: uid,
                gene: utf8(gene),
                birthday: timestamp_ms,
                metadata: table::new(ctx),
                name: utf8(b"Aida"),
                description: utf8(b"Aida"),
                image_url: utf8(imageUrl),
                creator: utf8(b"cheng"),
                link: utf8(b"https://aidameta.io"),
                project_url: utf8(b"https://aidameta.io"),
                level: 1,
            };

            // let sender = tx_context::sender(ctx);
            transfer::public_transfer(cb, owner);

            vector::push_back(&mut gd.aidaKey, id); 

            let user_nft = &mut gd.userNFT;
            if (table::contains(user_nft, owner)) {
                let v = table::borrow_mut(user_nft, owner);
                vector::push_back(v, id);
            }
            else {
                let newVector=vector::empty<ID>();
                vector::push_back(&mut newVector, id);
                table::add(user_nft, owner, newVector);
            }
        }
        else {
            abort 1
        }
    }

    public entry fun create_crystal_ball_pay(clock: &Clock, gd: &mut GlobalData, sui: &mut Coin<SUI>, ctx: &mut TxContext) {

    }

    public entry fun burn(cb: CrystalBall) {
        let CrystalBall { id, gene: _, birthday: _, metadata, name: _, description: _, image_url: _, creator: _, link: _, project_url: _, level: _ } = cb;
        object::delete(id);

        table::destroy_empty(metadata);
    }

    public entry fun add_crystal_ball_meta(clock: &Clock, cb: &mut CrystalBall, name: String, url: String, description: String) {

        let length = table::length(&cb.metadata);

        let meta = Meta {
            id: length + 1,
            url: url,
            name: name,
            description: description,
            publish: clock::timestamp_ms(clock),
            tag: utf8(b""),
            path: utf8(b"")
        };

        table::add(&mut cb.metadata, length + 1, meta);
    }

    public entry fun change_crystal_ball_meta(cb: &mut CrystalBall, metaid: u64, name: String, url: String, description: String) {

        let metaTable  = &mut cb.metadata;
        if (table::contains(metaTable, metaid)) {
            let meta = table::borrow_mut(metaTable, metaid);
            meta.url = url;
            meta.name = name;
            meta.description = description;
        }
    }

    public fun get_user_nft_object(gd: &mut GlobalData, userAddress: address, startIndex: u64, pageSize: u64): (vector<ID>, u64, u64){
        let t = &mut gd.userNFT;
        if (table::contains(t, userAddress)) {
            let src = table::borrow(t, userAddress);
            let results = vector::empty<ID>();
            let length = vector::length(src);
            let i = startIndex;
            while(i < startIndex + pageSize && i <= length) {
                let v :&ID = vector::borrow<ID>(src, i);
                vector::push_back<ID>(&mut results, *v);
                i = i + 1;
            };

            (results, length, i)
        }
        else {
            (vector::empty<ID>(), 0, 0)
        }
    }

    public fun get_crystal_ball_meta(cb: &mut CrystalBall,  startIndex: u64, pageSize: u64): (vector<Meta>, u64, u64) {
        let results = vector::empty<Meta>();
        let length = table::length(&cb.metadata);
        let i = startIndex;
        while( i < startIndex + pageSize && i <= length ) {
            let v :&Meta = table::borrow(&cb.metadata, i);
            let metaCopy = Meta {
                id: v.id ,
                url: v.url,
                name: v.name,
                description: v.description,
                publish: v.publish,
                tag: v.tag,
                path: v.path
            };
            vector::push_back<Meta>(&mut results, metaCopy);
            i = i + 1;
        };

        (results, length, i)
    }

    public fun generate_random_gene(lastSeed: u64, seed: u64): (vector<u8>, u64) {
        let a = 48271u128;
        let m = 2147483647u128;
        let lastSeed_u128 = (lastSeed as u128);
        let seed_u123 = (seed as u128);
        let si: u128 = lastSeed_u128 * seed_u123 % m;
        let base: vector<u8> = b"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        let index: u8 = 0;
        let gene: vector<u8> = vector::empty<u8>();
        while (index < 36) {
            si = si * a % m;
            let key = si % 128 % 36;
            let v:&u8 = vector::borrow<u8>(&base, (key as u64));
            vector::push_back<u8>(&mut gene, *v);
            index = index + 1;
        };

        (gene, (si as u64))
    }

    public entry fun change_owner(gd: &mut GlobalData, userAddress: address, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        if (gd.owner == sender) {
            gd.owner = userAddress;
        }
        else {
            abort 1
        }
    }

    public entry fun add_crystal_ball_publisher(gd: &mut GlobalData, userAddress: address, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        if (gd.owner == sender) {
            if (!vector::contains(&gd.publisher, &userAddress)) {
                vector::push_back(&mut gd.publisher, userAddress);
            }
        }
        else {
            abort 1
        }
    }

    public entry fun levelup_crystal_ball(cb: &mut CrystalBall, cbBurn: CrystalBall) {
        if (cb.level == cbBurn.level) {
            let CrystalBall { id, gene: _, birthday: _, metadata, name: _, description: _, image_url: _, creator: _, link: _, project_url: _, level: _ } = cbBurn;
            object::delete(id);

            table::destroy_empty(metadata);

            cb.level = cb.level + 1;
        }
        else {
            abort 1
        }
    }

    fun calc_crystal_level_piece(level: u64): u64 {
        let result: u64 = 1;
        let i: u64 = 1;
        while (i < level ) {
            result = result * 2;
            i = i + 1;
        };

        result
    }

    fun calc_crystal_total_level_piece(cbList:& vector<CrystalBall>) : u64 {
        let length = vector::length(cbList);
        let i = 0;
        let level: u64 = 0;

        while(i < length) {
            let cb = vector::borrow(cbList, i);
            level = level + calc_crystal_level_piece(cb.level);
            i = i + 1;
        };

        level
    }
}


#[test_only]
module crystalBall::test {
    // use sui::test_scenario;
    use crystalBall::aida;
    use std::debug;
    use std::string::{utf8};

    #[test]
    fun test_counter() {
        let (gene, _si) = aida::generate_random_gene(1234, 5678);
        let str = utf8(gene);
        debug::print(&str);
    }
}