// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {TinyLend} from "../src/TinyLend.sol";
import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";

// mock ERC20 token for testing
contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }
}

contract TinyLendTest is Test {
    TinyLend public tinyLend;
    MockToken public mockToken;
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        tinyLend = new TinyLend();
        mockToken = new MockToken();

        // fund test accounts
        mockToken.transfer(alice, 10000 * 10 ** 18);
        mockToken.transfer(bob, 10000 * 10 ** 18);
    }

    function test_InitialMarketState() public view {
        // check initial market state
        (
            uint256 supplyAcc,
            uint256 borrowAcc,
            uint256 totalSupplyShares,
            uint256 totalBorrowShares,
            uint256 totalBorrowUnderlying,
            uint256 lastAccrual
        ) = tinyLend.markets(address(mockToken));

        assertEq(supplyAcc, 0, "initial supply accumulator should be 0");
        assertEq(borrowAcc, 0, "initial borrow accumulator should be 0");
        assertEq(totalSupplyShares, 0, "initial total supply shares should be 0");
        assertEq(totalBorrowShares, 0, "initial total borrow shares should be 0");
        assertEq(totalBorrowUnderlying, 0, "initial total borrow underlying should be 0");
        assertEq(lastAccrual, 0, "initial last accrual timestamp should be 0");
    }

    function test_Deposit() public {
        uint256 depositAmount = 100 * 10 ** 18;

        vm.startPrank(alice);
        mockToken.approve(address(tinyLend), depositAmount);
        tinyLend.deposit(address(mockToken), depositAmount);

        uint256 supplied = tinyLend.suppliedUnderlying(alice, address(mockToken));
        assertEq(supplied, depositAmount, "supplied amount should match deposit amount");
        vm.stopPrank();
    }

    function test_Withdraw() public {
        uint256 depositAmount = 100 * 10 ** 18;
        uint256 withdrawAmount = 50 * 10 ** 18;

        vm.startPrank(alice);
        mockToken.approve(address(tinyLend), depositAmount);
        tinyLend.deposit(address(mockToken), depositAmount);

        uint256 balanceBefore = mockToken.balanceOf(alice);
        tinyLend.withdraw(address(mockToken), withdrawAmount);
        uint256 balanceAfter = mockToken.balanceOf(alice);

        assertEq(balanceAfter - balanceBefore, withdrawAmount, "token balance increase should match withdrawal amount");
        assertEq(
            tinyLend.suppliedUnderlying(alice, address(mockToken)),
            depositAmount - withdrawAmount,
            "remaining supplied amount should be deposit minus withdrawal"
        );
        vm.stopPrank();
    }

    function test_BorrowAndRepay() public {
        // first deposit some tokens
        uint256 depositAmount = 1000 * 10 ** 18;
        uint256 borrowAmount = 500 * 10 ** 18;

        vm.startPrank(alice);
        mockToken.approve(address(tinyLend), depositAmount);
        tinyLend.deposit(address(mockToken), depositAmount);
        vm.stopPrank();

        // now borrow
        vm.startPrank(bob);
        uint256 balanceBefore = mockToken.balanceOf(bob);
        tinyLend.borrow(address(mockToken), borrowAmount);
        uint256 balanceAfter = mockToken.balanceOf(bob);

        assertEq(balanceAfter - balanceBefore, borrowAmount, "token balance increase should match borrow amount");
        assertEq(
            tinyLend.borrowedUnderlying(bob, address(mockToken)),
            borrowAmount,
            "borrowed amount should match requested amount"
        );

        // repay the loan
        mockToken.approve(address(tinyLend), borrowAmount);
        tinyLend.repay(address(mockToken), borrowAmount);
        assertEq(
            tinyLend.borrowedUnderlying(bob, address(mockToken)), 0, "borrowed amount should be 0 after full repayment"
        );
        vm.stopPrank();
    }

    function test_InterestAccrual() public {
        // deposit and borrow
        uint256 depositAmount = 1000 * 10 ** 18;
        uint256 borrowAmount = 500 * 10 ** 18;

        vm.startPrank(alice);
        mockToken.approve(address(tinyLend), depositAmount);
        tinyLend.deposit(address(mockToken), depositAmount);
        vm.stopPrank();

        vm.startPrank(bob);
        mockToken.approve(address(tinyLend), type(uint256).max); // approve for repay
        tinyLend.borrow(address(mockToken), borrowAmount);
        vm.stopPrank();

        // advance time by 1 year
        vm.warp(block.timestamp + 365 days);

        // trigger accrual by calling a function that uses _accrue
        vm.startPrank(alice);
        mockToken.approve(address(tinyLend), 1);
        tinyLend.deposit(address(mockToken), 1);
        vm.stopPrank();

        // check that interest has accrued
        uint256 borrowedAmount = tinyLend.borrowedUnderlying(bob, address(mockToken));
        assertGt(borrowedAmount, borrowAmount, "borrowed amount should increase due to interest accrual");

        uint256 suppliedAmount = tinyLend.suppliedUnderlying(alice, address(mockToken));
        assertGt(suppliedAmount, depositAmount, "supplied amount should increase due to interest accrual");
    }
}
