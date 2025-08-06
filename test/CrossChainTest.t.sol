// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {CCIPLocalSimulatorFork, Register} from "../lib/chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interface/IRebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {RegistryModuleOwnerCustom} from "../lib/ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "../lib/ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {Client} from "lib/ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "../lib/ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {IERC20} from "../lib/ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
// Import your project-specific contracts
// Import the Chainlink Local simulator
contract CrossChainTest is Test {
    uint256 sepoliaFork;
    uint256 arbSepoliaFork;
    CCIPLocalSimulatorFork ccipLocalSimulatorFork;
    RebaseToken sepoliaToken;
    RebaseToken arbSepoliaToken;
    Vault vault;
    RebaseTokenPool sepoliaPool;
    RebaseTokenPool arbSepoliaPool;
    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbSepoliaNetworkDetails;
    address owner;
    address user;

    function setUp() external {
        // fork链
        sepoliaFork = vm.createSelectFork("sepolia");
        arbSepoliaFork = vm.createFork("arb-spolia");
        // 将ccip部署到所有链上
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));
        // 设置owner部署者
        owner = makeAddr("owner");
        user = makeAddr("user");

        // 部署pool，并为其增加权限
        // 这里的rmnProxy以及Router地址都来源于ccipLocalSimulatorFork.getNetworkDetails(chainId);
        // 进行nominate提名和接受(谁进行调用，谁就进行了提名)，这里需要用到
        // RegistryModuleOwnerCustom 以及 TokenAdminRegistry
        // 它里面需要的地址在ccipLocalSimulatorFork的NetworkDetail中获取即可
        // 使用TokenAdminRegister.setPool() 将对应的Token映射到对应的pool上

        /////////////////
        // sepolia部署 //
        ////////////////
        vm.startPrank(owner);
        sepoliaToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(sepoliaToken)));
        // 部署pool并为其增加mint和burn的权限
        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(
            block.chainid
        );
        sepoliaPool = new RebaseTokenPool(
            IERC20(address(sepoliaToken)),
            new address[](0),
            sepoliaNetworkDetails.rmnProxyAddress,
            sepoliaNetworkDetails.routerAddress
        );
        sepoliaToken.grantMintAndBurnRole(address(sepoliaPool));
        // 进行提名和接受
        RegistryModuleOwnerCustom(
            sepoliaNetworkDetails.registryModuleOwnerCustomAddress
        ).registerAdminViaOwner(address(sepoliaToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress)
            .acceptAdminRole(address(sepoliaToken));
        // Token映射
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress)
            .setPool(address(sepoliaToken), address(sepoliaPool));
        vm.stopPrank();

        ////////////////////
        // arbSepolia部署 //
        ///////////////////
        vm.selectFork(arbSepoliaFork);
        vm.startPrank(owner);
        arbSepoliaToken = new RebaseToken();

        // 部署pool并为其增加mint和burn的权限
        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(
            block.chainid
        );
        arbSepoliaPool = new RebaseTokenPool(
            IERC20(address(arbSepoliaToken)),
            new address[](0),
            arbSepoliaNetworkDetails.rmnProxyAddress,
            arbSepoliaNetworkDetails.routerAddress
        );
        arbSepoliaToken.grantMintAndBurnRole(address(arbSepoliaPool));
        // 进行提名和接受
        RegistryModuleOwnerCustom(
            arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress
        ).registerAdminViaOwner(address(arbSepoliaToken));
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress)
            .acceptAdminRole(address(arbSepoliaToken));
        // Token映射
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress)
            .setPool(address(arbSepoliaToken), address(arbSepoliaPool));
        vm.stopPrank();
    }

    function bridgeTokens(
        uint256 localForkId,
        uint256 remoteForkId,
        address _user,
        RebaseToken localToken,
        RebaseToken remoteToken,
        uint256 amountToBridge,
        Register.NetworkDetails memory localNetworkDetails,
        Register.NetworkDetails memory remoteNetworkDetails
    ) internal {
        // -- On localFork, pranking as user --
        vm.selectFork(localForkId);
        // Note: We use vm.prank(user) before each state-changing call instead of vm.startPrank/vm.stopPrank blocks.
        // 1. 初始化要传递的token类型以及数量
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(localToken), // Token address on the local chain
            amount: amountToBridge // Amount to transfer
        });
        // 2. 构造传递的信息
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(_user), // Receiver on the destination chain
            data: "", // No additional data payload in this example
            tokenAmounts: tokenAmounts, // The tokens and amounts to transfer
            feeToken: localNetworkDetails.linkAddress, // Using LINK as the fee token
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 100_000}) // Use default gas limit
            )
        });
        // 3. 获取需要的费用，并给对应的账户进行充值
        uint256 fee = IRouterClient(localNetworkDetails.routerAddress).getFee(
            remoteNetworkDetails.chainSelector, // Destination chain ID
            message
        );
        ccipLocalSimulatorFork.requestLinkFromFaucet(_user, fee);
        // 4. 批准支付Link费用(Link address)以及Router(user value)对应金额的使用权
        vm.prank(_user);
        IERC20(localNetworkDetails.linkAddress).approve(
            localNetworkDetails.routerAddress,
            fee
        );
        vm.prank(_user);
        IERC20(address(localToken)).approve(
            localNetworkDetails.routerAddress,
            amountToBridge
        );
        // 5. 获取用户的之前余额
        uint256 localBalanceBefore = localToken.balanceOf(_user);
        // 6. 发送CCIP信息
        vm.prank(_user);
        IRouterClient(localNetworkDetails.routerAddress).ccipSend(
            remoteNetworkDetails.chainSelector, // Destination chain ID
            message
        );
        // 7. 获取用户之后的余额，并进行对比
        uint256 localBalanceAfter = localToken.balanceOf(_user);
        assertEq(
            localBalanceAfter,
            localBalanceBefore - amountToBridge,
            "Local balance incorrect after send"
        );
        // 10. 模拟区块链的排队处理
        vm.warp(block.timestamp + 20 minutes); // Fast-forward time
        vm.selectFork(remoteForkId);
        // 11. 获取之前余额，并模拟发送信息，而后再获取之后的余额进行对比
        uint256 remoteBalanceBefore = remoteToken.balanceOf(_user);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteForkId);
        uint256 remoteBalanceAfter = remoteToken.balanceOf(_user);
        assertEq(
            remoteBalanceAfter,
            remoteBalanceBefore + amountToBridge,
            "Remote balance incorrect after receive"
        );

        // 14. Check interest rates (specific to RebaseToken logic)
        // IMPORTANT: localUserInterestRate should be fetched *before* switching to remoteFork
        // Example: Fetch localUserInterestRate while still on localFork
        // vm.selectFork(localFork);
        // uint256 localUserInterestRate = localToken.getUserInterestRate(user);
        // vm.selectFork(remoteFork); // Switch back if necessary or rely on switchChainAndRouteMessage
        //        uint256 remoteUserInterestRate = remoteToken.getUserInterestRate(user); // Called on remoteFork
        // assertEq(remoteUserInterestRate, localUserInterestRate, "Interest rates do not match");
    }

    function testBridgeAllTokens() public {
        uint256 DEPOSIT_AMOUNT = 1e5; // Using a small, fixed amount for clarity
        // 1. 抵押资金到sepolia
        vm.selectFork(sepoliaFork);
        vm.deal(user, DEPOSIT_AMOUNT); // Give user some ETH to deposit
        vm.prank(user);
        Vault(payable(address(vault))).deposit{value: DEPOSIT_AMOUNT}();
        assertEq(
            sepoliaToken.balanceOf(user),
            DEPOSIT_AMOUNT,
            "User Sepolia token balance after deposit incorrect"
        );
        // 2. Bridge Tokens: Sepolia -> Arbitrum Sepolia
        bridgeTokens(
            sepoliaFork,
            arbSepoliaFork,
            user,
            sepoliaToken,
            arbSepoliaToken,
            DEPOSIT_AMOUNT,
            sepoliaNetworkDetails,
            arbSepoliaNetworkDetails
        );
        // 3. Bridge All Tokens Back: Arbitrum Sepolia -> Sepolia
        vm.selectFork(arbSepoliaFork);
        vm.warp(block.timestamp + 20 minutes); // Advance time on Arbitrum Sepolia before bridging back
        uint256 arbBalanceToBridgeBack = arbSepoliaToken.balanceOf(user);
        assertTrue(
            arbBalanceToBridgeBack > 0,
            "User Arbitrum balance should be non-zero before bridging back"
        );
        bridgeTokens(
            arbSepoliaFork,
            sepoliaFork,
            user,
            arbSepoliaToken,
            sepoliaToken,
            arbBalanceToBridgeBack,
            arbSepoliaNetworkDetails,
            sepoliaNetworkDetails
        );
        vm.selectFork(sepoliaFork);
        assertEq(
            sepoliaToken.balanceOf(user),
            DEPOSIT_AMOUNT,
            "User Sepolia token balance after bridging back incorrect"
        );
    }
}
