# Description

Repository written by [Jose](https://github.com/josemvcerqueira) (move package) and [Thouny](https://github.com/thounyy) (interaction scripts) as part of [WBA Sui Cohort](https://github.com/Web3-Builders-Alliance/sui-course).

# Move Patterns

### Object wrapping

```rust
  struct CapWrapper has key {
    id: UID,
    cap: TreasuryCap<SUI_DOLLAR>
  }
```

It allows us to add access control to shared objects by wrapping them inside an object.

### Access control via capabilities and not via an `address`

```rust
  struct Bank has key {
    id: UID,
    balance: Balance<SUI>,
    admin_balance: Balance<SUI>,
  }

  struct Account has key, store {
    id: UID,
    user: address,
    debt: u64,
    deposit: u64
  }
```

We do store the user balance and debt inside an owned object that can be held by the user of another protocol. The owner of the `Account` object has the custody of the funds.

### Destroy functions

```rust
  public fun destroy_empty_account(account: Account) {
    let Account { id, debt: _, deposit, user: _ } = account;
    assert!(deposit == 0, EAccountMustBeEmpty);
    object::delete(id);
  }
```

The Sui blockchain gives Sui rebates when objects are deleted as it frees up storage slots. It is best practice to provide means for objects to be destroyed. Do keep in mind that you should ensure that the objects being deleted are empty to prevent loss of funds.

# PTBs

Using bun.sh.
Create your own .env.

### publish
Publish the package on Sui testnet. It writes the created objects to .created.json. This file is then used by ./utils/getId to easily retrieve the objects created during deployment.

### newAccount
Creates and sends a new Account object to the signer address.

### depositAndBorrow
Fetch a potential Account object for the user. Create one if it doesn't exist. Deposit the split SUI and borrow the given amount of DOLLAR.

### repayAndWithdraw
You can practice by writing the reverse transaction.
Repay the borrowed amount, then withdraw the deposited amount and finally destroy the Account object.
