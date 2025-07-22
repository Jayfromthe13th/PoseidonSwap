# PoseidonSwap AMM

A decentralized automated market maker (AMM) built on UMI Network using Move smart contracts.

## Deployment Information

**Network:** UMI Network Devnet  
**Contract Address:** 0x27f09A766ADadB3D5b3642455C940CF24F7aBc3A  
**Module Address:** 0x00000000000000000000000027f09A766ADadB3D5b3642455C940CF24F7aBc3A

## Deployed Modules

The following modules are deployed and operational:

* errors: Error handling system
* events: Event emission for off chain indexing
* math: AMM mathematical operations and calculations
* lp_token: Liquidity provider token management
* pool: Main AMM pool logic and operations
* umi_token: UMI token operations (mock implementation)
* shell_token: Shell token operations (mock implementation)
* apt_token: APT token operations (mock implementation)

## Features

* Create liquidity pools for UMI/Shell trading pairs
* Add and remove liquidity to earn fees
* Execute token swaps using constant product formula
* LP token minting and burning
* Event emission for transaction tracking
* Pause/resume functionality for pool management

## Module Addresses

All modules are deployed under the base address:
0x00000000000000000000000027f09A766ADadB3D5b3642455C940CF24F7aBc3A

Individual module access:
* poseidon_swap::errors
* poseidon_swap::events  
* poseidon_swap::math
* poseidon_swap::lp_token
* poseidon_swap::pool
* poseidon_swap::umi_token
* poseidon_swap::shell_token
* poseidon_swap::apt_token

## Development

Built with Move language and deployed using Hardhat with the Move plugin for UMI Network compatibility.

## Status

Deployed and operational on UMI Network devnet. Pool registry initialized and ready for AMM operations. 