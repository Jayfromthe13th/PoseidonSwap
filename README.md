# PoseidonSwap AMM - Math Module

A sophisticated mathematical engine for an Automated Market Maker (AMM) built on Aptos blockchain.

## Overview

PoseidonSwap is an AMM that enables APT/USDC token swapping through liquidity pools using the constant product formula (x*y=k). This repository contains the enhanced mathematical core that powers all AMM calculations.

## Features

### Advanced Mathematical Operations
- **Optimized square root function** using Babylonian method with 50-iteration precision
- **Safe arithmetic operations** with u128 casting to prevent overflow
- **Constant product formula** with built-in fee support
- **Price impact calculations** for better user experience
- **Slippage protection** with basis points precision

### Production-Ready Capabilities
- **K-invariant validation** ensures mathematical correctness
- **Optimal liquidity calculations** for efficient capital allocation
- **Comprehensive error handling** with proper error propagation
- **Frontend integration** with 8 view functions for real-time quotes

## Technical Specifications

- **Language**: Move 2 (Aptos)
- **Standards**: Fungible Asset (FA) standard
- **Architecture**: Object-based design
- **Testing**: 57 comprehensive tests with 100% pass rate

## Math Module Functions

### Core Calculations
- `calculate_swap_output()` - Basic constant product swap
- `calculate_swap_output_with_fee()` - Fee-inclusive swap calculations
- `calculate_price_impact()` - Price impact analysis
- `validate_k_invariant()` - Mathematical correctness validation

### Liquidity Operations
- `calculate_liquidity_amounts()` - LP token minting calculations
- `calculate_optimal_liquidity()` - Optimal ratio calculations
- `calculate_withdrawal_amounts()` - LP token burning calculations

### Utility Functions
- `sqrt()` - Enhanced square root with precision
- `check_slippage()` - Slippage tolerance validation
- `calculate_percentage()` - Basis points calculations

### View Functions (Frontend Integration)
- `quote_swap()` - Real-time swap quotes
- `quote_price_impact()` - Price impact quotes
- `quote_optimal_liquidity()` - Optimal liquidity quotes

## Testing

The math module includes comprehensive testing:
- **22 unit tests** covering all mathematical functions
- **35 integration tests** verifying cross-module interactions
- **Edge case testing** for overflow, underflow, and extreme values
- **Real AMM workflow simulation**

Run tests with:
```bash
aptos move test
```

## Development Status

**Current Phase**: Mathematical core complete
**Next Phase**: Pool operations integration
**Overall Progress**: ~40% complete

The mathematical foundation is production-ready. Remaining work focuses on integrating these calculations with actual token operations and user interface development.

## Architecture

```
PoseidonSwap/
├── Move.toml           # Project configuration
├── sources/
│   └── math.move       # Mathematical engine (this repo)
├── tests/
│   ├── math_tests.move # Unit tests
│   └── integration_tests.move # Integration tests
└── scripts/            # Deployment scripts
```

## License

MIT License - see LICENSE file for details.

## Contributing

This is the mathematical core of PoseidonSwap. For the complete AMM implementation including pool operations and frontend, see the main PoseidonSwap repository. 