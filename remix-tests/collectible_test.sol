// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20 <0.9.0;

import "remix_tests.sol";
import "../contracts/04-collectible-1155/CollectibleItems.sol";
import "../contracts/01-upgradeable/ExampleTimelock.sol";
import "../contracts/01-upgradeable/ExampleProxy.sol";

contract CollectibleTest {
    CollectibleItems items;

    function beforeAll() public {
        CollectibleItems implementation = new CollectibleItems();
        ExampleTimelock timelock = new ExampleTimelock(address(this), 1 days);
        ExampleProxy proxy = new ExampleProxy(address(implementation), address(timelock),
            abi.encodeCall(CollectibleItems.initialize, (address(this), address(this))));
        items = CollectibleItems(address(proxy));
    }

    function checkMintIntoAnAccount() public {
        uint256 id = items.mint(address(this), "greeting", false, "ipfs://g.json");
        Assert.equal(items.balanceOf(address(this), id), 1, "one of one");
        Assert.equal(items.uri(id), "ipfs://g.json", "its own metadata");
    }

    function checkApprovalsAreOff() public {
        try items.setApprovalForAll(address(0xB0B), true) { Assert.ok(false, "approvals must revert"); } catch { Assert.ok(true, "no operators"); }
        Assert.ok(!items.isApprovedForAll(address(this), address(0xB0B)), "nobody is approved");
    }

    // this test contract receives items, so it answers as an ERC-1155 receiver
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }
}
