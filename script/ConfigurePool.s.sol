// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {TokenPool} from "lib/ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "lib/ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";


/*
1. 准备 remotePoolAddress bytes[]数组
2. 准备 remoteTokenAddress地址
3. 构造TokenPool.chainUpdate[]数组，设置要设置的远程
4. 使用TokenPool(localPool).applyChainUpdate(new uint64[](), chainsAdd)
这里第一个参数是要移除的远程address，后者是要添加或者更新的
**/
contract ConfigurePool is Script {
    function run (
        address localPool,
        uint64 remoteChainSelector,
        address remotePool,
        address remoteToken,
        bool outboundRateLimiterIsEnabled,
        uint128 outboundRateLimiterCapacity,
        uint128 outboundRateLimiterRate,
        bool inboundRateLimiterIsEnabled,
        uint128 inboundRateLimiterCapacity,
        uint128 inboundRateLimiterRate
    ) public {
        vm.startBroadcast();
        bytes[] memory remotePoolAddress = new bytes[](1);
        remotePoolAddress[0] = abi.encode(remotePool);
        bytes memory remoteTokenAddress = abi.encode(remoteToken);
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            remotePoolAddress: remotePoolAddress[0],
            remoteTokenAddress: remoteTokenAddress,
            allowed: true,
            outboundRateLimiterConfig: RateLimiter.Config({
            isEnabled: outboundRateLimiterIsEnabled,
            capacity: outboundRateLimiterCapacity,
            rate: outboundRateLimiterRate
        }),
            inboundRateLimiterConfig: RateLimiter.Config({
            isEnabled: inboundRateLimiterIsEnabled,
            capacity: inboundRateLimiterCapacity,
            rate: inboundRateLimiterRate})
        });
        TokenPool(localPool).applyChainUpdates( chainsToAdd);
        vm.stopBroadcast();
    }
}