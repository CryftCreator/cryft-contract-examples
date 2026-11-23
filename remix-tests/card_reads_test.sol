// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import "remix_tests.sol";
import "../contracts/02-card-reads/CardStatusReader.sol";
import "../tests/support/MockCards.sol";

contract CardReadsTest {
    MockCryftCards cards;
    MockCardAuthority authority;
    CardStatusReader reader;

    function beforeAll() public {
        cards = new MockCryftCards();
        authority = new MockCardAuthority();
        reader = new CardStatusReader(address(cards), address(authority));
    }

    function checkAnOpenedCardIsLive() public {
        cards.set(7, true, false, false, false, address(this));
        authority.set(7, 3, address(0xCA7D));
        Assert.ok(reader.isLiveOpenedCard(7), "minted + opened = live");
        Assert.equal(reader.requireLiveOpenedCard(7), address(0xCA7D), "names the card's account");
    }

    function checkABurnedCardIsNotLive() public {
        cards.set(8, true, true, false, false, address(this));
        authority.set(8, 4, address(0));
        Assert.ok(!reader.isLiveOpenedCard(8), "burned is not live");
        Assert.equal(reader.metadataOf(8), "", "no metadata, and no revert");
    }
}
