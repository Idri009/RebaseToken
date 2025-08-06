# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Development Commands

### Testing
- Run all tests: `forge test`
- Run specific test: `forge test --match-test testName`
- Run tests with gas report: `forge test --gas-report`
- Run fuzz tests: `forge test --fuzz-runs 1000`

### Building and Compilation
- Build the project: `forge build`
- Clean build artifacts: `forge clean`

### Code Quality
- Format code: `forge fmt`
- Check code style: `forge fmt --check`

## Project Architecture

This is a Foundry-based Solidity project implementing a rebase token system with a vault for ETH deposits and rewards.

### Core Components

**RebaseToken (`src/RebaseToken.sol`)**
- ERC20 token with interest-bearing capabilities
- Uses OpenZeppelin's ERC20, Ownable, and AccessControl
- Key features:
  - Interest rates that can only decrease (owner control)
  - Per-user interest rates set at mint time
  - Interest accrual calculated based on time elapsed
  - Role-based access control for mint/burn operations
  - Special transfer logic that handles interest inheritance

**Vault (`src/Vault.sol`)**
- Manages ETH deposits and withdrawals
- Mints RebaseTokens 1:1 with ETH deposits
- Burns tokens and returns ETH on redemption
- Has MINT_AND_BURN role on RebaseToken

**IRebaseToken (`src/interface/IRebaseToken.sol`)**
- Interface defining core rebase token functions

### Key Architecture Patterns

**Interest Calculation System:**
- Global interest rate (`s_interestRate`) starts at 5e10 (0.00000005%)
- Users get the current global rate when they first receive tokens
- Interest compounds continuously based on time elapsed
- `_mintAccruedInterest()` converts accumulated interest to actual tokens
- `balanceOf()` returns principal + accrued interest

**Role-Based Access Control:**
- Uses OpenZeppelin's AccessControl with custom `MINT_AND_BURN` role
- Only addresses with this role can mint/burn tokens
- Vault contract is granted this role during setup

**Transfer Mechanics:**
- When transferring to a new user (zero balance), recipient inherits sender's interest rate
- Both sender and recipient have their interest minted before transfer
- Supports max value transfers (type(uint256).max)

### Testing Structure

Tests are in `test/RebaseTokenTest.t.sol` using Foundry's testing framework:
- Fuzz testing for deposit/redeem operations
- Interest accrual verification over time
- Transfer and inheritance logic testing
- Access control validation
- Edge case handling (max amounts, zero deposits)

### Development Setup

The project uses:
- OpenZeppelin contracts for standard implementations
- Foundry for development, testing, and deployment
- Remapping: `@openzeppelin/=lib/openzeppelin-contracts/`

### Important Constants

- `PRECISION_FACTOR = 1e18` - Used for interest calculations
- Default interest rate: `5e10` (very small rate for demonstration)
- Role identifier: `MINT_AND_BURN = keccak256("MINT_AND_BURN")`