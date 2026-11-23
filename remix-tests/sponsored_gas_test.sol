// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Cryft Labs. Written for these examples.
// See NOTICE and provenance.json.
pragma solidity >=0.8.20 <0.9.0;

import "remix_tests.sol";
import "../contracts/03-sponsored-gas/SponsoredGuestbook.sol";
import "../contracts/03-sponsored-gas/WalletDailyPolicy.sol";

/// This test contract stands in for the GasSponsor, so it may call the policy's hooks.
contract SponsoredGasTest {
    SponsoredGuestbook book;
    WalletDailyPolicy policy;

    function beforeAll() public {
        book = new SponsoredGuestbook();
        policy = new WalletDailyPolicy(address(this), address(0xACC0), address(this), 2e15, 4e15);
    }

    function checkTheGuestbookBoundsItsInput() public {
        try book.sign("") { Assert.ok(false, "an empty message must revert"); } catch { Assert.ok(true, "empty refused"); }
        book.sign("hello");
        Assert.equal(book.entries(), 1, "one entry");
    }

    function checkThePolicyHoldsTheDailyLimit() public {
        address alice = address(0xA11CE);
        policy.reserve(keccak256("op-1"), alice, 2e15);
        policy.reserve(keccak256("op-2"), alice, 2e15);
        try policy.reserve(keccak256("op-3"), alice, 1) { Assert.ok(false, "over the day must revert"); } catch { Assert.ok(true, "day full"); }
        policy.settle(keccak256("op-1"), 1e15);
        try policy.settle(keccak256("op-1"), 1) { Assert.ok(false, "a settled operation can't settle again"); } catch { Assert.ok(true, "no replay"); }
    }
}
