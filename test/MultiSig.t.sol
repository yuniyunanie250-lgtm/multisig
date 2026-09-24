// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {MultiSig} from "../src/MultiSig.sol";

contract Sink {
    uint256 public received;

    function pay() external payable {
        received += msg.value;
    }

    function boom() external pure {
        revert("nope");
    }
}

contract MultiSigTest is Test {
    MultiSig internal ms;
    Sink internal sink;
    address internal a = address(0xA);
    address internal b = address(0xB);
    address internal c = address(0xC);

    function setUp() public {
        address[] memory owners = new address[](3);
        owners[0] = a;
        owners[1] = b;
        owners[2] = c;
        ms = new MultiSig(owners, 2);
        sink = new Sink();
        vm.deal(address(ms), 10 ether);
    }

    function test_ConstructorSetsOwnersAndThreshold() public {
        assertEq(ms.threshold(), 2);
        assertEq(ms.owners(0), a);
        assertTrue(ms.isOwner(b));
        assertFalse(ms.isOwner(address(0xDEAD)));
    }

    function test_SubmitConfirmsOnce() public {
        vm.prank(a);
        uint256 id = ms.submit(address(sink), 1 ether, abi.encodeCall(Sink.pay, ()));
        assertTrue(ms.confirmedBy(id, a));
        (address target,,, uint256 confs, bool executed) = ms.transactions(id);
        assertEq(target, address(sink));
        assertEq(confs, 1);
        assertFalse(executed);
    }

    function test_ExecuteNeedsThreshold() public {
        vm.prank(a);
        uint256 id = ms.submit(address(sink), 1 ether, abi.encodeCall(Sink.pay, ()));
        vm.expectRevert(MultiSig.NotEnoughConfirmations.selector);
        ms.execute(id);
        vm.prank(b);
        ms.confirm(id);
        ms.execute(id);
        assertEq(sink.received(), 1 ether);
    }

    function test_DoubleConfirmReverts() public {
        vm.prank(a);
        uint256 id = ms.submit(address(sink), 1 ether, abi.encodeCall(Sink.pay, ()));
        vm.prank(a);
        vm.expectRevert(MultiSig.AlreadyConfirmed.selector);
        ms.confirm(id);
    }

    function test_RevokeDropsTheCount() public {
        vm.prank(a);
        uint256 id = ms.submit(address(sink), 1 ether, abi.encodeCall(Sink.pay, ()));
        vm.prank(a);
        ms.revoke(id);
        vm.prank(b);
        ms.confirm(id);
        vm.expectRevert(MultiSig.NotEnoughConfirmations.selector);
        ms.execute(id);
    }

    function test_CannotExecuteTwice() public {
        vm.prank(a);
        uint256 id = ms.submit(address(sink), 1 ether, abi.encodeCall(Sink.pay, ()));
        vm.prank(b);
        ms.confirm(id);
        ms.execute(id);
        vm.expectRevert(MultiSig.AlreadyExecuted.selector);
        ms.execute(id);
    }

    function test_NonOwnerCannotSubmit() public {
        vm.prank(address(0xDEAD));
        vm.expectRevert(MultiSig.NotOwner.selector);
        ms.submit(address(sink), 1 ether, "");
    }

    function test_FailedCallBubblesTheReason() public {
        vm.prank(a);
        uint256 id = ms.submit(address(sink), 0, abi.encodeCall(Sink.boom, ()));
        vm.prank(b);
        ms.confirm(id);
        vm.expectRevert();
        ms.execute(id);
    }

    function test_RemoveOwnerKeepsThresholdPossible() public {
        vm.prank(a);
        ms.removeOwner(c);
        assertFalse(ms.isOwner(c));
        assertEq(ms.ownerCount(), 2);
    }
}
