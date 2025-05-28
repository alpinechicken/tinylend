# TinyLend

TinyLend is a minimal lending protocol implementation designed for testing and integration purposes. It provides a simplified version of common lending protocol functionality while maintaining the core mechanics of supply, borrow, and interest accrual.

## Overview

TinyLend implements a basic lending protocol with the following features:
- Supply and withdraw assets
- Borrow and repay assets
- Interest accrual (5% fixed APR)
- Share-based accounting system
- Single collateral type support

## Technical Details

### Core Components

- **Market**: Tracks supply and borrow rates, total shares, and underlying amounts
- **Account**: Manages user supply and borrow positions
- **Interest Model**: Simple fixed-rate model (5% APR)

### Key Functions

```solidity
function deposit(address col, uint256 amt) external
function withdraw(address col, uint256 amt) external
function borrow(address col, uint256 amt) external
function repay(address col, uint256 amt) external
```

### Accounting System

TinyLend uses a share-based accounting system:
- Supply shares represent a user's share of the total supplied assets
- Borrow shares represent a user's share of the total borrowed assets
- Interest accrual is handled through accumulator variables

## Usage

TinyLend is primarily intended for:
- Testing integration with lending protocols
- Prototyping lending-related features
- Educational purposes
- Development and testing environments

## Development

### Setup

```bash
# Install dependencies
forge install

# Run tests
forge test
```

### Testing

The test suite includes examples of:
- Basic deposit/withdraw operations
- Borrow/repay functionality
- Interest accrual verification
- Market state management

## Security

⚠️ **Important**: TinyLend is not intended for production use. It lacks many security features and optimizations that would be necessary in a real lending protocol.

## License

MIT
