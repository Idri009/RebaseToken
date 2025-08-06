// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "../lib/forge-std/src/Test.sol";
import {Vault} from "../src/Vault.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {IRebaseToken} from "../src/interface/IRebaseToken.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IAccessControl} from "../lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;
    address owner = makeAddr("owner");
    address user = makeAddr("user");
    address user2 = makeAddr("user2");
    uint256 private constant START_BALANCE = 100 ether;

    function setUp() public {
        vm.startPrank(owner);
        vm.deal(owner, START_BALANCE);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));

        // Grant MINT_AND_BURN role to vault
        rebaseToken.grantMintAndBurnRole(address(vault));

        // Add initial funds to vault for redemptions
        (bool success,) = payable(address(vault)).call{value: START_BALANCE}("");
        require(success, "Failed to fund vault");
        vm.stopPrank();
    }

    function testDepositLinear(uint256 amount) public {
        // Constrain the fuzzed 'amount' to a practical range.
        // Min: 0.00001 ETH (1e5 wei), Max: type(uint96).max to avoid overflows.
        amount = bound(amount, 1e5, type(uint96).max);

        // 1. User deposits 'amount' ETH
        vm.startPrank(user); // Actions performed as 'user'
        vm.deal(user, amount); // Give 'user' the 'amount' of ETH to deposit

        vault.deposit{value: amount}(); // Example

        uint256 initialBalance = rebaseToken.balanceOf(user);

        uint256 timeDelta = 1 days; // Example
        vm.warp(block.timestamp + timeDelta);
        uint256 balanceAfterFirstWarp = rebaseToken.balanceOf(user);
        uint256 interestFirstPeriod = balanceAfterFirstWarp - initialBalance;

        vm.warp(block.timestamp + timeDelta); // Warp by another 'timeDelta'
        uint256 balanceAfterSecondWarp = rebaseToken.balanceOf(user);
        uint256 interestSecondPeriod = balanceAfterSecondWarp - balanceAfterFirstWarp;

        assertApproxEqAbs(
            interestFirstPeriod, interestSecondPeriod, 1, "Interest accrual should be approximately linear"
        );

        vm.stopPrank(); // Stop impersonating 'user'
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        vm.startPrank(user);
        vm.deal(user, amount);

        // User deposits
        vault.deposit{value: amount}();

        uint256 userEthBalanceBefore = user.balance;

        // User redeems immediately
        vault.redeem(type(uint256).max);

        uint256 userEthBalanceAfter = user.balance;
        uint256 userTokenBalanceAfter = rebaseToken.balanceOf(user);

        // Assertions
        assertEq(userTokenBalanceAfter, 0, "User should have 0 rebase tokens after redemption");
        assertApproxEqAbs(
            userEthBalanceAfter,
            userEthBalanceBefore + amount,
            1e15,
            "User ETH balance should be approximately equal to deposited amount"
        );

        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(uint256 depositAmount, uint256 time) public {
        depositAmount = bound(depositAmount, 1e5, type(uint96).max);
        time = bound(time, 1, type(uint96).max);

        vm.startPrank(user);
        vm.deal(user, depositAmount);

        // User deposits
        vault.deposit{value: depositAmount}();
        uint256 initialEthBalance = user.balance;

        // Time passes
        vm.warp(block.timestamp + time);

        uint256 balanceAfterSomeTime = rebaseToken.balanceOf(user);
        uint256 rewardAmount = balanceAfterSomeTime > depositAmount ? balanceAfterSomeTime - depositAmount : 0;

        vm.stopPrank();

        // Add rewards to vault to ensure it has enough funds
        addRewardsToVault(rewardAmount);

        vm.startPrank(user);

        // User redeems after time has passed
        vault.redeem(type(uint256).max);

        uint256 finalEthBalance = user.balance;

        // Assertion: User should have more ETH than initially deposited due to interest
        assertGe(
            finalEthBalance, initialEthBalance + depositAmount, "User should have more ETH due to accrued interest"
        );

        vm.stopPrank();
    }

    function addRewardsToVault(uint256 rewardAmount) public {
        vm.deal(address(this), rewardAmount);
        (bool success,) = payable(address(vault)).call{value: rewardAmount}("");
        require(success, "Failed to add rewards to vault");
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1, amount);

        vm.startPrank(user);
        vm.deal(user, amount);

        // User deposits
        vault.deposit{value: amount}();

        // Owner reduces global interest rate
        vm.stopPrank();
        vm.startPrank(owner);
        uint256 originalRate = 5e10;
        uint256 newRate = 4e10;
        rebaseToken.setInterestRate(newRate);
        vm.stopPrank();

        vm.startPrank(user);

        // User transfers tokens to user2
        rebaseToken.transfer(user2, amountToSend);

        // Check balances
        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 user2Balance = rebaseToken.balanceOf(user2);

        assertEq(userBalance + user2Balance, amount, "Total balance should be conserved");
        assertEq(user2Balance, amountToSend, "User2 should receive correct amount");

        // Check that user2 inherited user's interest rate (original rate)
        assertEq(rebaseToken.getUserInterestRate(user2), originalRate, "User2 should inherit user's interest rate");
        assertEq(rebaseToken.getUserInterestRate(user), originalRate, "User should keep original interest rate");

        vm.stopPrank();
    }

    function testGetPrincipleAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        vm.startPrank(user);
        vm.deal(user, amount);

        // User deposits
        vault.deposit{value: amount}();

        // Check principal balance immediately
        assertEq(rebaseToken.principleBalanceOf(user), amount, "Principal balance should equal deposited amount");

        // Time passes
        vm.warp(block.timestamp + 1 days);

        // Principal balance should remain unchanged
        assertEq(
            rebaseToken.principleBalanceOf(user), amount, "Principal balance should remain unchanged after time passes"
        );

        // But regular balance should have increased
        assertGt(rebaseToken.balanceOf(user), amount, "Regular balance should have increased due to interest");

        vm.stopPrank();
    }

    // Access Control Tests
    function testCannotSetInterestRate(uint256 newInterestRate) public {
        newInterestRate = bound(newInterestRate, 0, 5e10);

        vm.prank(user); // User is not the owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testCannotCallMintAndBurn() public {
        vm.prank(user); // User does not have MINT_AND_BURN_ROLE
        vm.expectRevert();
        rebaseToken.mint(user, 1 ether);

        vm.prank(user);
        vm.expectRevert();
        rebaseToken.burn(user, 1 ether);
    }

    function testOwnerCanSetInterestRate() public {
        uint256 newRate = 3e10;

        vm.prank(owner);
        rebaseToken.setInterestRate(newRate);

        // Verify the rate was set by checking a new user gets this rate
        vm.startPrank(user);
        vm.deal(user, 1 ether);
        vault.deposit{value: 1 ether}();

        assertEq(rebaseToken.getUserInterestRate(user), newRate, "New user should get the updated interest rate");
        vm.stopPrank();
    }

    function testInterestRateCanOnlyDecrease() public {
        uint256 higherRate = 6e10;

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(RebaseToken.RebaseToken_InterestRateOnlyDecrease.selector));
        rebaseToken.setInterestRate(higherRate);
    }

    function testDepositMustBeGreaterThanZero() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Vault.Vault_DepositAmountMustGreaterThanZero.selector));
        vault.deposit{value: 0}();
    }

    function testTransferFrom(uint256 amount, uint256 amountToTransfer) public {
        amount = bound(amount, 1e5, type(uint96).max);
        amountToTransfer = bound(amountToTransfer, 1, amount);

        vm.startPrank(user);
        vm.deal(user, amount);

        // User deposits
        vault.deposit{value: amount}();

        // User approves user2 to spend tokens
        rebaseToken.approve(user2, amountToTransfer);
        vm.stopPrank();

        // User2 transfers from user to themselves
        vm.prank(user2);
        rebaseToken.transferFrom(user, user2, amountToTransfer);

        // Check balances
        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 user2Balance = rebaseToken.balanceOf(user2);

        assertEq(user2Balance, amountToTransfer, "User2 should receive correct amount");
        assertEq(userBalance + user2Balance, amount, "Total balance should be conserved");
    }

    function testBurnWithMaxAmount() public {
        uint256 amount = 1 ether;

        vm.startPrank(user);
        vm.deal(user, amount);

        // User deposits
        vault.deposit{value: amount}();

        // Time passes to accrue interest
        vm.warp(block.timestamp + 1 days);

        uint256 balanceBeforeBurn = rebaseToken.balanceOf(user);
        vm.stopPrank();

        // Vault burns all tokens (using type(uint256).max)
        vm.prank(address(vault));
        rebaseToken.burn(user, type(uint256).max);

        uint256 balanceAfterBurn = rebaseToken.balanceOf(user);

        assertEq(balanceAfterBurn, 0, "User should have 0 balance after burning max amount");
        assertGt(balanceBeforeBurn, amount, "Balance should have been greater than initial deposit due to interest");
    }

    function testInterestAccrualOverTime() public {
        uint256 amount = 1 ether;

        vm.startPrank(user);
        vm.deal(user, amount);

        // User deposits
        vault.deposit{value: amount}();

        uint256 initialBalance = rebaseToken.balanceOf(user);

        // Time passes
        vm.warp(block.timestamp + 365 days);

        uint256 finalBalance = rebaseToken.balanceOf(user);

        assertGt(finalBalance, initialBalance, "Balance should increase over time due to interest");

        vm.stopPrank();
    }
}
