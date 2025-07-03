/// Mathematical operations for PoseidonSwap AMM
module poseidon_swap::math {
    use poseidon_swap::errors;

    // Constants for precision and calculations
    const MAX_U64: u128 = 18446744073709551615;
    const PRECISION_FACTOR: u64 = 1000000; // 6 decimal places for precision
    const MIN_LIQUIDITY: u64 = 1000; // Minimum liquidity to prevent division by zero
    const MAX_SLIPPAGE_BPS: u64 = 10000; // 100% in basis points

    /// Calculate swap output using constant product formula: (x * y = k)
    /// Formula: output = (reserve_out * amount_in) / (reserve_in + amount_in)
    public fun calculate_swap_output(
        reserve_in: u64,
        reserve_out: u64,
        amount_in: u64
    ): u64 {
        assert!(reserve_in > 0, errors::division_by_zero());
        assert!(reserve_out > 0, errors::division_by_zero());
        assert!(amount_in > 0, errors::insufficient_input_amount());

        // Use u128 to prevent overflow during multiplication
        let reserve_in_u128 = (reserve_in as u128);
        let reserve_out_u128 = (reserve_out as u128);
        let amount_in_u128 = (amount_in as u128);

        let numerator = reserve_out_u128 * amount_in_u128;
        let denominator = reserve_in_u128 + amount_in_u128;
        
        assert!(denominator > 0, errors::division_by_zero());
        
        let result = numerator / denominator;
        assert!(result <= MAX_U64, errors::overflow());
        
        (result as u64)
    }

    /// Calculate swap output with fee support (for future fee implementation)
    /// Formula: output = (reserve_out * amount_in * (10000 - fee_bps)) / ((reserve_in * 10000) + (amount_in * (10000 - fee_bps)))
    public fun calculate_swap_output_with_fee(
        reserve_in: u64,
        reserve_out: u64,
        amount_in: u64,
        fee_bps: u64 // Fee in basis points (e.g., 30 = 0.3%)
    ): u64 {
        assert!(reserve_in > 0, errors::division_by_zero());
        assert!(reserve_out > 0, errors::division_by_zero());
        assert!(amount_in > 0, errors::insufficient_input_amount());
        assert!(fee_bps <= MAX_SLIPPAGE_BPS, errors::invalid_swap_amount());

        let reserve_in_u128 = (reserve_in as u128);
        let reserve_out_u128 = (reserve_out as u128);
        let amount_in_u128 = (amount_in as u128);
        let fee_bps_u128 = (fee_bps as u128);

        let amount_in_with_fee = amount_in_u128 * (10000 - fee_bps_u128);
        let numerator = reserve_out_u128 * amount_in_with_fee;
        let denominator = (reserve_in_u128 * 10000) + amount_in_with_fee;
        
        assert!(denominator > 0, errors::division_by_zero());
        
        let result = numerator / denominator;
        assert!(result <= MAX_U64, errors::overflow());
        
        (result as u64)
    }

    /// Calculate price impact of a swap
    /// Returns price impact in basis points (e.g., 100 = 1%)
    public fun calculate_price_impact(
        reserve_in: u64,
        reserve_out: u64,
        amount_in: u64
    ): u64 {
        assert!(reserve_in > 0, errors::division_by_zero());
        assert!(reserve_out > 0, errors::division_by_zero());
        assert!(amount_in > 0, errors::insufficient_input_amount());

        // Current price: reserve_out / reserve_in
        let current_price = multiply_u64(reserve_out, PRECISION_FACTOR) / reserve_in;
        
        // Calculate output amount
        let amount_out = calculate_swap_output(reserve_in, reserve_out, amount_in);
        
        // New price after swap: (reserve_out - amount_out) / (reserve_in + amount_in)
        let new_reserve_in = reserve_in + amount_in;
        let new_reserve_out = reserve_out - amount_out;
        let new_price = multiply_u64(new_reserve_out, PRECISION_FACTOR) / new_reserve_in;
        
        // Price impact = |current_price - new_price| / current_price * 10000
        let price_diff = if (current_price > new_price) {
            current_price - new_price
        } else {
            new_price - current_price
        };
        
        (price_diff * 10000) / current_price
    }

    /// Validate that the constant product invariant is maintained
    /// Returns true if k_new >= k_old (allowing for rounding)
    public fun validate_k_invariant(
        old_reserve_a: u64,
        old_reserve_b: u64,
        new_reserve_a: u64,
        new_reserve_b: u64
    ): bool {
        let old_k = multiply_u128(old_reserve_a, old_reserve_b);
        let new_k = multiply_u128(new_reserve_a, new_reserve_b);
        
        // Allow for small rounding errors (new_k should be >= old_k - 1)
        new_k >= old_k || (old_k - new_k <= 1)
    }

    /// Calculate liquidity amounts for LP token minting with enhanced precision
    public fun calculate_liquidity_amounts(
        umi_amount: u64,
        shell_amount: u64,
        umi_reserve: u64,
        shell_reserve: u64,
        total_supply: u64
    ): u64 {
        if (total_supply == 0) {
            // Initial liquidity: geometric mean minus minimum liquidity
            let initial_liquidity = sqrt(multiply_u64(umi_amount, shell_amount));
            assert!(initial_liquidity > MIN_LIQUIDITY, errors::insufficient_liquidity_minted());
            initial_liquidity - MIN_LIQUIDITY
        } else {
            assert!(umi_reserve > 0, errors::division_by_zero());
            assert!(shell_reserve > 0, errors::division_by_zero());
            
            // Subsequent liquidity: proportional to existing reserves
            let umi_liquidity = multiply_u64(umi_amount, total_supply) / umi_reserve;
            let shell_liquidity = multiply_u64(shell_amount, total_supply) / shell_reserve;
            min(umi_liquidity, shell_liquidity)
        }
    }

    /// Calculate optimal liquidity amounts to maintain pool ratio
    /// Returns (optimal_umi_amount, optimal_shell_amount)
    public fun calculate_optimal_liquidity(
        desired_umi: u64,
        desired_shell: u64,
        umi_reserve: u64,
        shell_reserve: u64
    ): (u64, u64) {
        assert!(umi_reserve > 0, errors::division_by_zero());
        assert!(shell_reserve > 0, errors::division_by_zero());
        
        // Calculate the ratio-optimal amounts
        let umi_based_shell = multiply_u64(desired_umi, shell_reserve) / umi_reserve;
        let shell_based_umi = multiply_u64(desired_shell, umi_reserve) / shell_reserve;
        
        if (umi_based_shell <= desired_shell) {
            (desired_umi, umi_based_shell)
        } else {
            (shell_based_umi, desired_shell)
        }
    }

    /// Calculate withdrawal amounts when burning LP tokens
    public fun calculate_withdrawal_amounts(
        lp_amount: u64,
        umi_reserve: u64,
        shell_reserve: u64,
        total_supply: u64
    ): (u64, u64) {
        assert!(total_supply > 0, errors::division_by_zero());
        assert!(lp_amount <= total_supply, errors::insufficient_liquidity_burned());

        let umi_amount = multiply_u64(lp_amount, umi_reserve) / total_supply;
        let shell_amount = multiply_u64(lp_amount, shell_reserve) / total_supply;
        
        (umi_amount, shell_amount)
    }

    /// Enhanced square root function using Babylonian method with better precision
    public fun sqrt(x: u64): u64 {
        if (x == 0) return 0;
        if (x <= 3) return 1;
        if (x == 4) return 2;

        // Use a better initial guess
        let z = x;
        let y = (x + 1) / 2;
        
        // More iterations for better precision
        let iterations = 0;
        while (y < z && iterations < 50) {
            z = y;
            y = (x / y + y) / 2;
            iterations = iterations + 1;
        };
        
        z
    }

    /// Square root function for u64 values (alias for sqrt)
    public fun sqrt_u64(x: u64): u64 {
        sqrt(x)
    }

    /// Calculate square root with u128 precision for large numbers
    public fun sqrt_u128(x: u128): u128 {
        if (x == 0) return 0;
        if (x <= 3) return 1;
        if (x == 4) return 2;

        let z = x;
        let y = (x + 1) / 2;
        
        let iterations = 0;
        while (y < z && iterations < 100) {
            z = y;
            y = (x / y + y) / 2;
            iterations = iterations + 1;
        };
        
        z
    }

    /// Safe multiplication that checks for overflow (u64)
    public fun multiply_u64(a: u64, b: u64): u64 {
        let result_u128 = (a as u128) * (b as u128);
        assert!(result_u128 <= MAX_U64, errors::overflow());
        (result_u128 as u64)
    }

    /// Safe multiplication for u128 values
    public fun multiply_u128(a: u64, b: u64): u128 {
        (a as u128) * (b as u128)
    }

    /// Safe addition that checks for overflow
    public fun add_u64(a: u64, b: u64): u64 {
        let result_u128 = (a as u128) + (b as u128);
        assert!(result_u128 <= MAX_U64, errors::overflow());
        (result_u128 as u64)
    }

    /// Safe subtraction that checks for underflow
    public fun sub_u64(a: u64, b: u64): u64 {
        assert!(a >= b, errors::overflow());
        a - b
    }

    /// Calculate percentage with basis points precision
    /// Returns (value * percentage_bps) / 10000
    public fun calculate_percentage(value: u64, percentage_bps: u64): u64 {
        assert!(percentage_bps <= MAX_SLIPPAGE_BPS, errors::invalid_swap_amount());
        multiply_u64(value, percentage_bps) / 10000
    }

    /// Check slippage tolerance
    /// Returns true if actual_amount is within tolerance of expected_amount
    public fun check_slippage(
        expected_amount: u64,
        actual_amount: u64,
        slippage_tolerance_bps: u64
    ): bool {
        assert!(slippage_tolerance_bps <= MAX_SLIPPAGE_BPS, errors::invalid_swap_amount());
        
        let tolerance = calculate_percentage(expected_amount, slippage_tolerance_bps);
        let min_acceptable = if (expected_amount > tolerance) {
            expected_amount - tolerance
        } else {
            0
        };
        let max_acceptable = expected_amount + tolerance;
        
        actual_amount >= min_acceptable && actual_amount <= max_acceptable
    }

    /// Return minimum of two values
    public fun min(a: u64, b: u64): u64 {
        if (a < b) a else b
    }

    /// Return maximum of two values
    public fun max(a: u64, b: u64): u64 {
        if (a > b) a else b
    }

    /// Check if values are approximately equal (within specified tolerance)
    public fun approximately_equal(a: u64, b: u64, tolerance_bps: u64): bool {
        let diff = if (a > b) a - b else b - a;
        let tolerance = calculate_percentage(max(a, b), tolerance_bps);
        diff <= tolerance
    }

    // View functions for testing and verification
    #[view]
    public fun quote_swap(
        reserve_in: u64,
        reserve_out: u64,
        amount_in: u64
    ): u64 {
        calculate_swap_output(reserve_in, reserve_out, amount_in)
    }

    #[view]
    public fun quote_swap_with_fee(
        reserve_in: u64,
        reserve_out: u64,
        amount_in: u64,
        fee_bps: u64
    ): u64 {
        calculate_swap_output_with_fee(reserve_in, reserve_out, amount_in, fee_bps)
    }

    #[view]
    public fun quote_liquidity(
        umi_amount: u64,
        shell_amount: u64,
        umi_reserve: u64,
        shell_reserve: u64,
        total_supply: u64
    ): u64 {
        calculate_liquidity_amounts(umi_amount, shell_amount, umi_reserve, shell_reserve, total_supply)
    }

    #[view]
    public fun quote_price_impact(
        reserve_in: u64,
        reserve_out: u64,
        amount_in: u64
    ): u64 {
        calculate_price_impact(reserve_in, reserve_out, amount_in)
    }

    #[view]
    public fun quote_optimal_liquidity(
        desired_umi: u64,
        desired_shell: u64,
        umi_reserve: u64,
        shell_reserve: u64
    ): (u64, u64) {
        calculate_optimal_liquidity(desired_umi, desired_shell, umi_reserve, shell_reserve)
    }

    // Constants getters for external use
    public fun get_precision_factor(): u64 { PRECISION_FACTOR }
    public fun get_min_liquidity(): u64 { MIN_LIQUIDITY }
    public fun get_max_slippage_bps(): u64 { MAX_SLIPPAGE_BPS }

    // Test and verification functions
    #[view]
    public fun test_constant_product_invariant(
        reserve_a: u64,
        reserve_b: u64,
        amount_in: u64
    ): bool {
        // Test that x * y = k is maintained after a swap
        let amount_out = calculate_swap_output(reserve_a, reserve_b, amount_in);
        let new_reserve_a = reserve_a + amount_in;
        let new_reserve_b = reserve_b - amount_out;
        
        validate_k_invariant(reserve_a, reserve_b, new_reserve_a, new_reserve_b)
    }

    #[view]
    public fun get_k_value(reserve_a: u64, reserve_b: u64): u128 {
        multiply_u128(reserve_a, reserve_b)
    }
} 