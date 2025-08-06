// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRebaseToken} from "./interface/IRebaseToken.sol";

// (Imports will be added later)
contract Vault {
    error Vault_DepositAmountMustGreaterThanZero();
    error Vault_RedeemFailed();

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    IRebaseToken private immutable i_rebaseToken;

    constructor(IRebaseToken rebaseToken) {
        i_rebaseToken = rebaseToken;
    }

    // Allow the contract to receive ETH
    receive() external payable {}

    function deposit() external payable {
        uint256 amountToMint = msg.value;
        if (amountToMint == 0) {
            revert Vault_DepositAmountMustGreaterThanZero();
        }
        i_rebaseToken.mint(msg.sender, amountToMint);
        emit Deposit(msg.sender, amountToMint);
    }

    function redeem(uint256 _amount) external {
        // Check Effects Interactions
        uint256 amountToRedeem = _amount;
        if (_amount == type(uint256).max) {
            amountToRedeem = i_rebaseToken.balanceOf(msg.sender);
        }

        // Effects
        i_rebaseToken.burn(msg.sender, amountToRedeem);

        // Interactions
        (bool success,) = payable(msg.sender).call{value: amountToRedeem}("");

        if (!success) {
            revert Vault_RedeemFailed();
        }
        emit Redeem(msg.sender, amountToRedeem);
    }
}
