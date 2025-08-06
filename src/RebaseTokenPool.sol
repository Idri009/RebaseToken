// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Pool} from "../lib/ccip/contracts/src/v0.8/ccip/libraries/Pool.sol";
import {TokenPool} from "../lib/ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {IERC20} from
    "../lib/ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {IRebaseToken} from "./interface/IRebaseToken.sol";

contract RebaseTokenPool is TokenPool {
    constructor(IERC20 _token, address[] memory _allowlist, address _rnmProxy, address _router)
        TokenPool(_token, _allowlist, _rnmProxy, _router){}

    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn)
        external
        override
        returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut)
    {
        _validateLockOrBurn(lockOrBurnIn);
        address originalSender = lockOrBurnIn.originalSender;

        // 获取额外信息
        uint256 userInterestRate = IRebaseToken(address(i_token)).getUserInterestRate(originalSender);
        // burn对应数量的Token
        IRebaseToken(address(i_token)).burn(address(this), lockOrBurnIn.amount);
        // 准备output data数据给ccip
        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(userInterestRate) // Encode the interest rate to send cross-chain
        });
    }

    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn)
        external
        override
        returns (Pool.ReleaseOrMintOutV1 memory /* releaseOrMintOut */ )
    {
        _validateReleaseOrMint(releaseOrMintIn);

        address receiver = releaseOrMintIn.receiver;
        // 为对应用户铸造相应数量的币
        IRebaseToken(address(i_token)).mint(
            receiver,
            releaseOrMintIn.amount
        );
        // 创造信息并返回给ccip
        return Pool.ReleaseOrMintOutV1({destinationAmount: releaseOrMintIn.amount});
    }
}
