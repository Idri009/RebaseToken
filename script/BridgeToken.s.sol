// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "../lib/forge-std/src/Script.sol";
import {Client} from "lib/ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "../lib/ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {IERC20} from "../lib/ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

/*
1. Construct the CCIP Message: Create an EVM2AnyMessage struct containing all details for the cross-chain transfer.
2. Approve Token to Send: Grant the CCIP Router permission to spend the ERC20 tokens being bridged.
3. Calculate CCIP Fee: Query the CCIP Router to determine the fee required for the transaction.
4. Approve Fee Token: Grant the CCIP Router permission to spend the fee token (e.g., LINK).
5. Execute CCIP Send: Call the ccipSend function on the CCIP Router to initiate the transfer.
**/
contract BridgeToken is Script {
    function run (
        address receiverAddress,
        uint64 destinationChainSelector,
        address tokenToSendAddress,
        uint256 amountToSend,
        address linkTokenAddress,
        address routerAddress
    ) public {
        // 准备发送信息
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount(
             tokenToSendAddress,
             amountToSend
        );
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage(
            abi.encode(receiverAddress),
            '',
            tokenAmounts,
            linkTokenAddress,
            Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 0}))
        );

        // 计算fee，并进行批准
        uint256 ccipFee = IRouterClient(routerAddress).getFee(destinationChainSelector, message);
        IERC20(linkTokenAddress).approve(routerAddress, ccipFee);
        IERC20(tokenToSendAddress).approve(routerAddress, amountToSend);
        // 发送
        IRouterClient(routerAddress).ccipSend(destinationChainSelector, message);
    }

}
