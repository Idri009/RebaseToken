// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "../lib/forge-std/src/Script.sol";
import {Vault} from "../src/Vault.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {CCIPLocalSimulatorFork, Register} from "../lib/chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {RegistryModuleOwnerCustom} from "../lib/ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "../lib/ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {IERC20} from "../lib/ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {IRebaseToken} from "../src/interface/IRebaseToken.sol";
/*
1. Deploy a RebaseToken contract.
2. Deploy a RebaseTokenPool contract.
3. Deploy a Vault contract.
4. Configure all necessary permissions for Cross-Chain Interoperability Protocol (CCIP) integration.
**/

contract LocalDeployer is Script{
    function run() public returns (RebaseToken token, RebaseTokenPool pool, Vault vault) {
        CCIPLocalSimulatorFork ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        Register.NetworkDetails memory networkDetails = ccipLocalSimulatorFork
            .getNetworkDetails(block.chainid);
        uint256 deployerKey = vm.envUint('PRIVATE_KEY');
        vm.startBroadcast(deployerKey);
        // 创建token pool，并授权pool
        token = new RebaseToken();
        // 注意这里的IERC20需要从ccip中导入
        pool = new RebaseTokenPool(
            IERC20(address(token)),
            new address[](0),
            networkDetails.rmnProxyAddress,
            networkDetails.routerAddress
        );
        token.grantMintAndBurnRole(address(pool));
        // 进行提名和接受(看函数内部逻辑 这里授权的是owner 在接受的时候根据发送人进行判断的)
        RegistryModuleOwnerCustom(
            networkDetails.registryModuleOwnerCustomAddress
        ).registerAdminViaOwner(address(token));
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress)
        .acceptAdminRole(address(token));
        // Token映射
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).setPool(
            address(token),
            address(pool)
        );
        // 进行vault部署
        vault = new Vault(IRebaseToken(address (token)));
        IRebaseToken(address (token)).grantMintAndBurnRole(address(vault));
        // 进行授权
        IRebaseToken(address (token)).grantMintAndBurnRole(address (pool));
        vm.stopBroadcast();
    }
}

contract RemoteDeployer is Script{
    function run() public returns (RebaseToken token, RebaseTokenPool pool) {
        CCIPLocalSimulatorFork ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        Register.NetworkDetails memory networkDetails = ccipLocalSimulatorFork
            .getNetworkDetails(block.chainid);
        uint256 deployerKey = vm.envUint('PRIVATE_KEY');
        vm.startBroadcast(deployerKey);
        // 创建token pool，并授权pool
        token = new RebaseToken();
        // 注意这里的IERC20需要从ccip中导入
        pool = new RebaseTokenPool(
            IERC20(address(token)),
            new address[](0),
            networkDetails.rmnProxyAddress,
            networkDetails.routerAddress
        );
        token.grantMintAndBurnRole(address(pool));
        // 进行提名和接受(看函数内部逻辑 这里授权的是owner 在接受的时候根据发送人进行判断的)
        RegistryModuleOwnerCustom(
            networkDetails.registryModuleOwnerCustomAddress
        ).registerAdminViaOwner(address(token));
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress)
        .acceptAdminRole(address(token));
        // Token映射
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).setPool(
            address(token),
            address(pool)
        );
        // 对pool进行授权
        IRebaseToken(address (token)).grantMintAndBurnRole(address (pool));
        vm.stopBroadcast();
    }
}

