module book_management::my_module {

    use sui::object::{Self, ID, UID};
    use sui::event;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};
    use std::string;
    use std::option::{Self, Option};

    struct Book has key, store {
        id: UID,
        name: string::String,
        author: string::String,
        description: string::String,
        is_available: bool,
        borrower: Option<address>,
        records: Table<u64, Record>,
    }

    struct Record has store, drop {
        borrower: address,
        borrowed_at: u64,
        returned_at: u64,
    }

    struct AddBookEvent has copy, drop {
        object_id: ID,
        name: string::String,
        author: string::String,
        description: string::String,
    }

    struct BorrowBookEvent has copy, drop {
        object_id: ID,
        borrower: address,
        borrowed_at: u64,
    }

    struct ReturnBookEvent has copy, drop {
        object_id: ID,
        borrower: address,
        borrowed_at: u64,
        returned_at: u64,
    }

    public entry fun add_book(
        name: vector<u8>,
        author: vector<u8>,
        description: vector<u8>,
        ctx: &mut TxContext
    ) {
        let book = Book {
            id: object::new(ctx),
            name: string::utf8(name),
            author: string::utf8(author),
            description: string::utf8(description),
            is_available: true,
            borrower: option::none(),
            records: sui::table::new<u64, Record>(ctx),
        };
        let sender = tx_context::sender(ctx);
        event::emit(AddBookEvent {
            object_id: object::uid_to_inner(&book.id),
            name: book.name,
            author: book.author,
            description: book.description,
        });
        transfer::public_transfer(book, sender);
    }

    public entry fun borrow_book(
        book: &mut Book,
        borrowed_at: u64,
        ctx: &mut TxContext
    ) {
        if (!book.is_available) {
            // panic!(b"Book is not available for borrowing.");
            return
        };
        let borrower = tx_context::sender(ctx);
        book.is_available = false;
        book.borrower = option::some(borrower);
        let record = Record {
            borrower,
            borrowed_at,
            returned_at: 0,
        };
        let record_id: u64 = table::length(&book.records);
        // book.records.insert(record_id, record);
        sui::table::add(&mut book.records, record_id, record);
        event::emit(BorrowBookEvent {
            object_id: object::uid_to_inner(&book.id),
            borrower,
            borrowed_at,
        });
    }

    public entry fun return_book(
        book: &mut Book,
        returned_at: u64,
        ctx: &mut TxContext
    ) {
        if (book.is_available) {
            // panic!(b"Book is already available.");
            return
        };
        let borrower = tx_context::sender(ctx);
        if (book.borrower != option::some(borrower)) {
            // panic!(b"You are not the borrower of this book.");
            return
        };
        let record_id: u64 = table::length(&book.records) - 1;
        let record = sui::table::borrow_mut(&mut book.records, record_id);
        record.returned_at = returned_at;
        book.is_available = true;
        book.borrower = option::none();
        event::emit(ReturnBookEvent {
            object_id: object::uid_to_inner(&book.id),
            borrower,
            borrowed_at: record.borrowed_at,
            returned_at,
        });
    }

    public fun get_book_records(book: &Book) : &Table<u64, Record> {
        &book.records
    }

    public fun is_book_available(book: &Book) : bool {
        book.is_available
    }

    public fun get_book_borrower(book: &Book) : Option<address> {
        book.borrower
    }

    public fun get_book_name(book: &Book) : &string::String {
        &book.name
    }

    public fun get_book_author(book: &Book) : &string::String {
        &book.author
    }

    public fun get_book_description(book: &Book) : &string::String {
        &book.description
    }
}