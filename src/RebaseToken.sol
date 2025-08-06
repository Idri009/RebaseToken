// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IRebaseToken} from "./interface/IRebaseToken.sol";

/**
 * @title RebaseToken
 * @author Your Name/Alias
 * @notice This is a cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards.
 * @notice The interest rate in the smart contract can only decrease.
 * @notice Each user will have their own interest rate that is the global interest rate at the time of deposit.
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken_InterestRateOnlyDecrease();

    event interestRateSet(uint256);

    uint256 private constant PRECISION_FACTOR = 1e18;
    uint256 private s_interestRate = 5e10; // 0.00000005%
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdateTimestamp;
    bytes32 public constant MINT_AND_BURN = keccak256("MINT_AND_BURN");

    constructor() ERC20("RebaseToken", "RBT") Ownable(msg.sender) {}

    /////////////////////////////////////////
    ////// public or external function //////
    ////////////////////////////////////////
    function setInterestRate(uint256 newInterestRate) external onlyOwner {
        if (newInterestRate > s_interestRate) {
            revert RebaseToken_InterestRateOnlyDecrease();
        }
        s_interestRate = newInterestRate;
        emit interestRateSet(newInterestRate);
    }

    function mint(address _to, uint256 _amount) external onlyRole(MINT_AND_BURN) {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    function balanceOf(address _user) public view override returns (uint256) {
        uint256 accumulateRate = _calculateUserAccumulatedInterestSinceLastUpdate(_user);
        return (super.balanceOf(_user) * accumulateRate) / PRECISION_FACTOR;
    }

    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN) {
        // 先获取现在的本金，然后更新本金的余额，最后进行燃烧
        uint256 currentBalance = balanceOf(_from);
        if (_amount == type(uint256).max) {
            _amount = currentBalance;
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        // 将两者的金额都更新到最新，然后进行转账
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);

        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_recipient) == 0 && _amount > 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }

        return super.transfer(_recipient, _amount);
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);

        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender); // Use the interest-inclusive balance of the _sender
        }
        // Set recipient's interest rate if they are new
        if (balanceOf(_recipient) == 0 && _amount > 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }

        return super.transferFrom(_sender, _recipient, _amount);
    }

    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN, _account);
    }

    /////////////////////////////////////////
    ////// internal or helper Function //////
    ////////////////////////////////////////
    function _mintAccruedInterest(address _user) internal {
        uint256 principalBalance = super.balanceOf(_user);
        uint256 interestFactor = _calculateUserAccumulatedInterestSinceLastUpdate(_user) - PRECISION_FACTOR;
        _mint(_user, (principalBalance * interestFactor) / PRECISION_FACTOR);
        s_userLastUpdateTimestamp[_user] = block.timestamp;
    }

    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user) internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - s_userLastUpdateTimestamp[_user];
        if (timeElapsed == 0 || s_userInterestRate[_user] == 0) {
            return PRECISION_FACTOR;
        }
        uint256 fractionalInterest = s_userInterestRate[_user] * timeElapsed;
        return PRECISION_FACTOR + fractionalInterest;
    }

    ///////////////////////////
    ////// Get Function //////
    //////////////////////////
    function principleBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }
}
