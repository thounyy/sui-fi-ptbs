import { TransactionBlock } from '@mysten/sui.js/transactions';
import { CoinBalance, PaginatedObjectsResponse, SuiObjectResponse } from '@mysten/sui.js/client';
import { client, keypair, getId } from './utils.js';

// This PTB creates an account if the user doesn't have one and deposit the required amount into the bank

(async () => {
	const getAccountForAddress = async (addr: string): Promise<string | undefined> => {
		let hasNextPage = true;
		let nextCursor = null;
		let account = undefined;
		
		while (hasNextPage) {
			const objects: PaginatedObjectsResponse = await client.getOwnedObjects({
			owner: addr,
			cursor: nextCursor,
			options: { showType: true },
			});

			account = objects.data?.find((obj: SuiObjectResponse) => obj.data?.type === `${getId("package")}::bank::Account`);
			hasNextPage = objects.hasNextPage;
			nextCursor = objects.nextCursor;

			if (account !== undefined) break;
		}

		return account?.data?.objectId;
	};

	const getSuiDollarBalance = async (): Promise<CoinBalance> => {
		return await client.getBalance({
			owner: keypair.getPublicKey().toSuiAddress(),
			coinType: `${getId("package")}::dollar::DOLLAR`,
		});
	}

	try {
		const tx = new TransactionBlock();
		// get the coin to deposit
		const [coin] = tx.splitCoins(tx.gas, [tx.pure(1000)]);
		
		const accountId = await getAccountForAddress(keypair.getPublicKey().toSuiAddress());
		// if the user has no account, we create one
		let account;
		if (accountId === undefined) {
			[account] = tx.moveCall({
				target: `${getId("package")}::bank::new_account`,
				arguments: [],
			});
		} else {
			account = tx.object(accountId);
		}
	
		tx.moveCall({
			target: `${getId("package")}::bank::deposit`,
			arguments: [
				tx.object(getId("bank::Bank")),
				account,
				coin,
			],
		});

		const [dollar] = tx.moveCall({
			target: `${getId("package")}::bank::borrow`,
			arguments: [
				account,
				tx.object(getId("dollar::CapWrapper")),
				tx.pure(500),
			],
		});

		tx.transferObjects([dollar], keypair.getPublicKey().toSuiAddress());

		// if the user has no account we transfer it
		if (accountId === undefined) {
			tx.transferObjects([account], keypair.getPublicKey().toSuiAddress());
		}

		const result = await client.signAndExecuteTransactionBlock({
			signer: keypair,
			transactionBlock: tx,
			options: {
				showObjectChanges: true,
				showEffects: true,
			},
			requestType: "WaitForLocalExecution"
		});

		console.log("result: ", JSON.stringify(result.objectChanges, null, 2));
		console.log("status: ", JSON.stringify(result.effects?.status, null, 2));

	} catch (e) {
		console.log(e)
	} finally{
		// get the total Sui Dollar Coins for the user
		const sd_bal = await getSuiDollarBalance();
		console.log(sd_bal);
	}
})()