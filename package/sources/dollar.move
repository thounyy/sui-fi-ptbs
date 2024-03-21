module sui_fi::dollar {
  use std::option;

  use sui::transfer;
  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;
  use sui::coin::{Self, Coin, TreasuryCap};

  struct DOLLAR has drop {}

  friend sui_fi::bank;

  struct CapWrapper has key {
    id: UID,
    cap: TreasuryCap<DOLLAR>
  }

  #[lint_allow(share_owned)]
  fun init(witness: DOLLAR, ctx: &mut TxContext) {
      let (treasury_cap, metadata) = coin::create_currency<DOLLAR>(
            witness, 
            9, 
            b"SUID",
            b"Sui Dollar", 
            b"Stable coin issued by Sui Bank", 
            option::none(), 
            ctx
        );

      transfer::share_object(CapWrapper { id: object::new(ctx), cap: treasury_cap });
      transfer::public_share_object(metadata);
  }

  public fun burn(cap: &mut CapWrapper, coin: Coin<DOLLAR>): u64 {
    coin::burn(&mut cap.cap, coin)
  }

  public(friend) fun mint(cap: &mut CapWrapper, value: u64, ctx: &mut TxContext): Coin<DOLLAR> {
    coin::mint(&mut cap.cap, value, ctx)
  }
}