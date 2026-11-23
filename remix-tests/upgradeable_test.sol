// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Cryft Labs. Written for these examples.
// See NOTICE and provenance.json.
pragma solidity >=0.8.20 <0.9.0;

import "remix_tests.sol";
import "../contracts/01-upgradeable/NoticeBoardV1.sol";
import "../contracts/01-upgradeable/NoticeBoardV2.sol";
import "../contracts/01-upgradeable/ExampleTimelock.sol";
import "../contracts/01-upgradeable/ExampleProxy.sol";

/// Remix: Solidity Unit Testing → run. (The pytest suite in tests/ covers the same and more, with time travel.)
contract UpgradeableTest {
    NoticeBoardV1 board;
    ExampleTimelock timelock;
    ExampleProxy proxy;
    NoticeBoardV1 implementation;

    function beforeAll() public {
        implementation = new NoticeBoardV1();
        timelock = new ExampleTimelock(address(this), 1 days);
        proxy = new ExampleProxy(address(implementation), address(timelock), abi.encodeCall(NoticeBoardV1.initialize, (address(this))));
        timelock.adopt(address(proxy));
        board = NoticeBoardV1(address(proxy));
    }

    function checkSetUpThroughTheProxy() public {
        Assert.equal(board.owner(), address(this), "the proxy was initialized in its constructor");
        Assert.equal(proxy.proxyAdmin(), address(timelock), "the timelock is the admin");
        Assert.equal(uint256(implementation.initializedVersion()), uint256(type(uint64).max), "the implementation itself is locked");
    }

    function checkNoticesAreBounded() public {
        try board.post("") { Assert.ok(false, "an empty notice must revert"); } catch { Assert.ok(true, "empty refused"); }
        board.post("hello");
        Assert.equal(board.noticeOf(address(this)), "hello", "posted through the proxy");
    }

    function checkAnUpgradeMustWait() public {
        NoticeBoardV2 v2 = new NoticeBoardV2();
        timelock.schedule(address(v2), abi.encodeCall(NoticeBoardV2.initializeV2, ()));
        try timelock.execute() { Assert.ok(false, "an upgrade can't run before its delay"); } catch { Assert.ok(true, "too early"); }
        timelock.cancel();
        Assert.equal(proxy.implementation(), address(implementation), "nothing changed");
    }
}
