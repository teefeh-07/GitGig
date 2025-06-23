
import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v0.31.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "User registration works correctly",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;

        let block = chain.mineBlock([
            Tx.contractCall('teefeh', 'register-user', [
                types.ascii("alice_freelancer"),
                types.ascii("freelancer")
            ], wallet1.address)
        ]);

        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectOk(), types.uint(1));

        // Check user data
        let userQuery = chain.callReadOnlyFn('teefeh', 'get-user', [
            types.principal(wallet1.address)
        ], deployer.address);

        const userData = userQuery.result.expectSome().expectTuple();
        assertEquals(userData['username'], types.ascii("alice_freelancer"));
        assertEquals(userData['user-type'], types.ascii("freelancer"));
        assertEquals(userData['user-id'], types.uint(1));
    },
});

Clarinet.test({
    name: "Cannot register user twice",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;

        let block = chain.mineBlock([
            Tx.contractCall('teefeh', 'register-user', [
                types.ascii("alice"),
                types.ascii("freelancer")
            ], wallet1.address),
            Tx.contractCall('teefeh', 'register-user', [
                types.ascii("alice2"),
                types.ascii("client")
            ], wallet1.address)
        ]);

        assertEquals(block.receipts.length, 2);
        assertEquals(block.receipts[0].result.expectOk(), types.uint(1));
        assertEquals(block.receipts[1].result.expectErr(), types.uint(105)); // err-already-exists
    },
});

Clarinet.test({
    name: "Gig creation and application flow",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const client = accounts.get('wallet_1')!;
        const freelancer = accounts.get('wallet_2')!;

        // Register users
        let block = chain.mineBlock([
            Tx.contractCall('teefeh', 'register-user', [
                types.ascii("client_bob"),
                types.ascii("client")
            ], client.address),
            Tx.contractCall('teefeh', 'register-user', [
                types.ascii("freelancer_alice"),
                types.ascii("freelancer")
            ], freelancer.address)
        ]);

        assertEquals(block.receipts.length, 2);
        assertEquals(block.receipts[0].result.expectOk(), types.uint(1));
        assertEquals(block.receipts[1].result.expectOk(), types.uint(2));

        // Create gig
        block = chain.mineBlock([
            Tx.contractCall('teefeh', 'create-gig', [
                types.ascii("Build a website"),
                types.ascii("Need a responsive website for my business"),
                types.uint(1000000), // 1 STX in microSTX
                types.uint(100) // deadline
            ], client.address)
        ]);

        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectOk(), types.uint(1));

        // Apply to gig
        block = chain.mineBlock([
            Tx.contractCall('teefeh', 'apply-to-gig', [
                types.uint(1),
                types.ascii("I can build your website with modern tech"),
                types.uint(900000) // 0.9 STX
            ], freelancer.address)
        ]);

        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectOk(), types.bool(true));
    },
});
Clarinet.test({
    name: "Complete gig workflow with payment",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const client = accounts.get('wallet_1')!;
        const freelancer = accounts.get('wallet_2')!;

        // Register users and create gig
        let block = chain.mineBlock([
            Tx.contractCall('teefeh', 'register-user', [
                types.ascii("client_bob"),
                types.ascii("client")
            ], client.address),
            Tx.contractCall('teefeh', 'register-user', [
                types.ascii("freelancer_alice"),
                types.ascii("freelancer")
            ], freelancer.address),
            Tx.contractCall('teefeh', 'create-gig', [
                types.ascii("Logo design"),
                types.ascii("Need a professional logo"),
                types.uint(500000), // 0.5 STX
                types.uint(50)
            ], client.address)
        ]);

        // Apply and accept freelancer
        block = chain.mineBlock([
            Tx.contractCall('teefeh', 'apply-to-gig', [
                types.uint(1),
                types.ascii("I'll create an amazing logo"),
                types.uint(500000)
            ], freelancer.address),
            Tx.contractCall('teefeh', 'accept-freelancer', [
                types.uint(1),
                types.principal(freelancer.address)
            ], client.address)
        ]);

        assertEquals(block.receipts.length, 2);
        assertEquals(block.receipts[0].result.expectOk(), types.bool(true));
        assertEquals(block.receipts[1].result.expectOk(), types.bool(true));

        // Fund escrow
        block = chain.mineBlock([
            Tx.contractCall('teefeh', 'fund-escrow', [
                types.uint(1)
            ], client.address)
        ]);

        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectOk(), types.bool(true));

        // Complete gig
        block = chain.mineBlock([
            Tx.contractCall('teefeh', 'complete-gig', [
                types.uint(1)
            ], client.address)
        ]);

        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectOk(), types.bool(true));

        // Rate the gig
        block = chain.mineBlock([
            Tx.contractCall('teefeh', 'rate-gig', [
                types.uint(1),
                types.uint(5),
                types.ascii("Excellent work!")
            ], client.address)
        ]);

        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectOk(), types.bool(true));
    },
});

Clarinet.test({
    name: "Error handling tests",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const client = accounts.get('wallet_1')!;
        const freelancer = accounts.get('wallet_2')!;

        // Try to create gig without being registered
        let block = chain.mineBlock([
            Tx.contractCall('teefeh', 'create-gig', [
                types.ascii("Test gig"),
                types.ascii("Description"),
                types.uint(100000),
                types.uint(50)
            ], client.address)
        ]);

        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectErr(), types.uint(101)); // err-not-found

        // Register and create gig
        block = chain.mineBlock([
            Tx.contractCall('teefeh', 'register-user', [
                types.ascii("client"),
                types.ascii("client")
            ], client.address),
            Tx.contractCall('teefeh', 'create-gig', [
                types.ascii("Test gig"),
                types.ascii("Description"),
                types.uint(100000),
                types.uint(50)
            ], client.address)
        ]);

        // Try to apply without being registered
        block = chain.mineBlock([
            Tx.contractCall('teefeh', 'apply-to-gig', [
                types.uint(1),
                types.ascii("My proposal"),
                types.uint(90000)
            ], freelancer.address)
        ]);

        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectErr(), types.uint(101)); // err-not-found

        // Try invalid rating
        block = chain.mineBlock([
            Tx.contractCall('teefeh', 'register-user', [
                types.ascii("freelancer"),
                types.ascii("freelancer")
            ], freelancer.address)
        ]);

        // This should fail because gig is not completed
        block = chain.mineBlock([
            Tx.contractCall('teefeh', 'rate-gig', [
                types.uint(1),
                types.uint(6), // Invalid rating > 5
                types.ascii("Test review")
            ], client.address)
        ]);

        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectErr(), types.uint(103)); // err-invalid-status
    },
});
