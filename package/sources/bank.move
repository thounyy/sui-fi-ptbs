module sui_fi::bank {
    use sui::sui::SUI;
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};

    use sui_fi::dollar::{Self, CapWrapper, DOLLAR};  

    struct Bank has key {
        id: UID,
        balance: Balance<SUI>,
        admin_balance: Balance<SUI>,
    }

    // store ability so transferrable and storable
    struct Account has key, store {
        id: UID,
        debt: u64,
        collateral: u64
    }

    // no store ability so not transferrable
    struct OwnerCap has key {
        id: UID
    }

    const ENotEnoughBalance: u64 = 0;
    const EBorrowAmountIsTooHigh: u64 = 1;
    const EAccountMustBeEmpty: u64 = 2;
    const EPayYourLoan: u64 = 3;

    const FEE: u128 = 500; // 5%
    const EXCHANGE_RATE: u128 = 140;

    fun init(ctx: &mut TxContext) {
        transfer::share_object(
            Bank {
                id: object::new(ctx),
                balance: balance::zero(),
                admin_balance: balance::zero()
            }
        );

        transfer::transfer(OwnerCap { id: object::new(ctx) }, tx_context::sender(ctx));
    }

    // === Public Mut Functions ===    

    public fun new_account(ctx: &mut TxContext): Account {
        Account {
            id: object::new(ctx),
            debt: 0,
            collateral: 0
        }
    } 

    public fun deposit(self: &mut Bank, account: &mut Account, token: Coin<SUI>, ctx: &mut TxContext) {
        let value = coin::value(&token);
        let deposit_value = value - (((value as u128) * FEE / 10000) as u64);
        let admin_fee = value - deposit_value;

        let admin_coin = coin::split(&mut token, admin_fee, ctx);
        balance::join(&mut self.admin_balance, coin::into_balance(admin_coin));
        balance::join(&mut self.balance, coin::into_balance(token));

        account.collateral = account.collateral + deposit_value;
    }  

    public fun withdraw(self: &mut Bank, account: &mut Account, value: u64, ctx: &mut TxContext): Coin<SUI> {
        assert!(account.debt == 0, EPayYourLoan);
        assert!(account.collateral >= value, ENotEnoughBalance);

        account.collateral = account.collateral - value;

        coin::from_balance(balance::split(&mut self.balance, value), ctx)
    }

    public fun borrow(account: &mut Account, cap: &mut CapWrapper, value: u64, ctx: &mut TxContext): Coin<DOLLAR> {
        let max_borrow_amount = (((account.collateral as u128) * EXCHANGE_RATE / 100) as u64);

        assert!(max_borrow_amount >= account.debt + value, EBorrowAmountIsTooHigh);

        account.debt = account.debt + value;

        dollar::mint(cap, value, ctx)
    }

    public fun repay(account: &mut Account, cap: &mut CapWrapper, coin: Coin<DOLLAR>) {
        let amount = dollar::burn(cap, coin);

        account.debt = account.debt - amount;
    }  
    
    public fun destroy_empty_account(account: Account) {
        let Account { id, debt: _, collateral } = account;
        assert!(collateral == 0, EAccountMustBeEmpty);
        object::delete(id);
    }  

    // === Public Read Functions ===    

    public fun balance(self: &Bank): u64 {
        balance::value(&self.balance)
    }

    public fun debt(account: &Account): u64 {
        account.debt
    } 

    public fun collateral(account: &Account): u64 {
        account.collateral
    }    

    public fun admin_balance(self: &Bank): u64 {
        balance::value(&self.admin_balance)
    }

    // === Admin Functions ===

    public fun claim(_: &OwnerCap, self: &mut Bank, ctx: &mut TxContext): Coin<SUI> {
        let value = balance::value(&self.admin_balance);
        coin::take(&mut self.admin_balance, value, ctx)
    }    
}