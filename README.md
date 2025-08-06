# Foundry Rebase Token

A Solidity smart contract system implementing a rebase token with interest-bearing capabilities and an ETH vault for deposits and redemptions.

## Overview

This project consists of two main contracts:

- **RebaseToken**: An ERC20 token that automatically accrues interest over time
- **Vault**: A contract that manages ETH deposits and mints/burns RebaseTokens

### Key Features

- **Interest Accrual**: Tokens automatically earn interest based on time elapsed
- **Individual Interest Rates**: Each user gets the global interest rate at the time of their first deposit
- **Decreasing Interest Rates**: The global interest rate can only be decreased by the owner
- **Interest Inheritance**: When transferring to new users, they inherit the sender's interest rate
- **Vault Integration**: Simple deposit/redeem functionality with 1:1 ETH-to-token peg
- **Role-Based Access**: Controlled minting and burning through role-based permissions

## Contracts

### RebaseToken.sol

The core rebase token contract that extends OpenZeppelin's ERC20 with interest-bearing functionality.

**Key Functions:**
- `mint(address _to, uint256 _amount)` - Mint tokens (restricted to MINT_AND_BURN role)
- `burn(address _from, uint256 _amount)` - Burn tokens (restricted to MINT_AND_BURN role)
- `balanceOf(address _user)` - Returns principal balance plus accrued interest
- `principleBalanceOf(address _user)` - Returns only the principal balance
- `setInterestRate(uint256 newInterestRate)` - Owner can decrease global interest rate
- `getUserInterestRate(address _user)` - Get user's individual interest rate

### Vault.sol

Manages ETH deposits and RebaseToken minting/burning.

**Key Functions:**
- `deposit()` - Deposit ETH and receive RebaseTokens
- `redeem(uint256 _amount)` - Burn RebaseTokens and receive ETH back

## Installation & Setup

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git

### Installation

```bash
git clone <repository-url>
cd foundry-rebase-token
forge install
```

### Dependencies

- OpenZeppelin Contracts for standard ERC20, Ownable, and AccessControl implementations
- Forge Standard Library for testing utilities

## Usage

### Building

```bash
forge build
```

### Testing

Run all tests:
```bash
forge test
```

Run specific test:
```bash
forge test --match-test testDepositLinear
```

Run tests with gas reporting:
```bash
forge test --gas-report
```

Run fuzz tests with more runs:
```bash
forge test --fuzz-runs 1000
```

### Code Formatting

```bash
forge fmt
```

### Deployment

The project includes RPC endpoints for Sepolia and Arbitrum Sepolia testnets configured in `foundry.toml`.

## Architecture

### Interest Calculation

The rebase mechanism works through continuous compound interest:

1. Each user has an individual interest rate set when they first receive tokens
2. Interest is calculated as: `principal * (1 + rate * timeElapsed)`
3. The `balanceOf()` function returns the interest-inclusive balance
4. Actual minting of interest tokens occurs during transfers, mints, or burns

### Transfer Logic

When transferring tokens:
1. Both sender and recipient have their accrued interest minted
2. If recipient has zero balance, they inherit sender's interest rate
3. Transfer proceeds normally with updated balances

### Access Control

- **Owner**: Can set interest rates and grant roles
- **MINT_AND_BURN Role**: Can mint and burn tokens (typically granted to the Vault contract)

## Testing

The test suite includes:

- **Fuzz Testing**: Randomized inputs for deposit/redeem operations
- **Interest Accrual**: Verification of linear interest growth over time
- **Transfer Mechanics**: Testing inheritance of interest rates
- **Access Control**: Ensuring proper permission restrictions
- **Edge Cases**: Max value transfers, zero deposits, etc.

## Security Considerations

- Interest rates can only decrease to prevent economic attacks
- Role-based access control for minting/burning operations
- Proper CEI (Checks-Effects-Interactions) pattern in vault operations
- Comprehensive test coverage including fuzz testing

## Constants

- `PRECISION_FACTOR`: 1e18 (used for interest calculations)
- Default Interest Rate: 5e10 (0.00000005% per second)
- Role Identifier: `keccak256("MINT_AND_BURN")`

## License

MIT License