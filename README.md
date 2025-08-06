## 任务计划
变量
1. 全局精确度(用于scale)
2. 全局的利率
3. 用户的利率
4. 用户的最近更新时间

函数实现
1. mint() // 会首先mint对应的利息给用户，然后更新利率以及他的最后更新时间
`_mintAccruedInterest(_to) 辅助函数`
2. balanceOf // 计算本金 * 利率因子_calculateUserAccumulatedInterestSinceLastUpdate(_user)
3. transfer：若对方没有本金，则继承该用户的利率，若用户有本金，则用户利率应不发生改变

注意
1. _ 在函数前面是为了表达该函数是内部的私有函数，不对外暴露


### Vault实现

// (Imports will be added later)
contract Vault {
// Core Requirements:
// 1. Store the address of the RebaseToken contract (passed in constructor).
// 2. Implement a deposit function:
//    - Accepts ETH from the user.
//    - Mints RebaseTokens to the user, equivalent to the ETH sent (1:1 peg initially).
// 3. Implement a redeem function:
//    - Burns the user's RebaseTokens.
//    - Sends the corresponding amount of ETH back to the user.
// 4. Implement a mechanism to add ETH rewards to the vault.
}

1. Deposit：收集用户的eth，然后为其铸造相同的代币
2. Redeem: 返回用户的eth

### 问题
1. transfer：低利息用户向高利息用户转账
2. 不断地进行burn和mint形成复利效应



Build the Message: Construct an EVM2AnyMessage struct containing details like the receiver's address, token transfer specifics, the fee token, and any extra arguments for CCIP.

Calculate Fees: Query the source chain's Router contract using getFee() to determine the cost of the CCIP transaction.

Fund Fees: In our local test setup, we'll use a helper function to mint LINK tokens (the designated fee token in this example) to the user.

Approve Fee Token: The user must approve the source chain's Router contract to spend the calculated LINK fee.

Approve Bridged Token: The user must also approve the source chain's Router to spend the amount of the token being bridged.

Send CCIP Message: Invoke ccipSend() on the source chain's Router, passing the destination chain selector and the prepared message.

Simulate Message Propagation: Utilize the CCIPLocalSimulatorFork to mimic the message's journey and processing on the destination chain, including fast-forwarding time to simulate network latency.

Verify Token Reception: Confirm that the tokens (and any associated data, like interest rates for a RebaseToken) are correctly credited to the receiver on the destination chain.