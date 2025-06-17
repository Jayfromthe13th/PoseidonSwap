#[test_only]
module poseidon_swap::math_tests {
    use poseidon_swap::math;
    use poseidon_swap::errors;

    // Test constants
    const PRECISION_FACTOR: u64 = 1000000;
    const MIN_LIQUIDITY: u64 = 1000;

    #[test]
    fun test_sqrt_basic() {
        assert!(math::sqrt(0) == 0, 1);
        assert!(math::sqrt(1) == 1, 2);
        assert!(math::sqrt(4) == 2, 3);
        assert!(math::sqrt(9) == 3, 4);
        assert!(math::sqrt(16) == 4, 5);
        assert!(math::sqrt(25) == 5, 6);
        assert!(math::sqrt(100) == 10, 7);
    }

    #[test]
    fun test_sqrt_precision() {
        // Test precision for larger numbers
        assert!(math::sqrt(10000) == 100, 1);
        assert!(math::sqrt(1000000) == 1000, 2);
        
        // Test precision for non-perfect squares
        let result = math::sqrt(15);
        assert!(result >= 3 && result <= 4, 3); // sqrt(15) ≈ 3.87
        
        let result2 = math::sqrt(50);
        assert!(result2 >= 7 && result2 <= 8, 4); // sqrt(50) ≈ 7.07
    }

    #[test]
    fun test_sqrt_edge_cases() {
        assert!(math::sqrt(2) == 1, 1);
        assert!(math::sqrt(3) == 1, 2);
        assert!(math::sqrt(8) == 2, 3); // Should round down
    }

    #[test]
    fun test_safe_math_operations() {
        // Test safe addition
        assert!(math::add_u64(100, 200) == 300, 1);
        assert!(math::add_u64(0, 100) == 100, 2);
        
        // Test safe subtraction
        assert!(math::sub_u64(300, 100) == 200, 3);
        assert!(math::sub_u64(100, 100) == 0, 4);
        
        // Test safe multiplication
        assert!(math::multiply_u64(10, 20) == 200, 5);
        assert!(math::multiply_u64(0, 100) == 0, 6);
        assert!(math::multiply_u64(100, 1) == 100, 7);
    }

    #[test]
    #[expected_failure(abort_code = 30)] // overflow error
    fun test_safe_math_overflow() {
        // This should fail with overflow
        math::multiply_u64(18446744073709551615, 2); // Max u64 * 2
    }

    #[test]
    #[expected_failure(abort_code = 30)] // overflow error  
    fun test_safe_subtraction_underflow() {
        // This should fail with underflow
        math::sub_u64(100, 200);
    }

    #[test]
    fun test_min_max() {
        assert!(math::min(10, 20) == 10, 1);
        assert!(math::min(20, 10) == 10, 2);
        assert!(math::min(15, 15) == 15, 3);
        
        assert!(math::max(10, 20) == 20, 4);
        assert!(math::max(20, 10) == 20, 5);
        assert!(math::max(15, 15) == 15, 6);
    }

    #[test]
    fun test_calculate_swap_output() {
        // Test basic swap calculation
        let reserve_in = 1000000; // 1M tokens
        let reserve_out = 2000000; // 2M tokens
        let amount_in = 100000; // 100K tokens
        
        let output = math::calculate_swap_output(reserve_in, reserve_out, amount_in);
        
        // Output should be less than proportional due to slippage
        let proportional = (amount_in * reserve_out) / reserve_in; // 200K
        assert!(output < proportional, 1);
        assert!(output > 0, 2);
        
        // Verify the calculation: output = (reserve_out * amount_in) / (reserve_in + amount_in)
        let expected = (reserve_out * amount_in) / (reserve_in + amount_in);
        assert!(output == expected, 3);
    }

    #[test]
    fun test_constant_product_invariant() {
        let reserve_a = 1000000;
        let reserve_b = 2000000;
        let amount_in = 50000;
        
        // Test that the invariant holds
        assert!(math::test_constant_product_invariant(reserve_a, reserve_b, amount_in), 1);
        
        // Test with different values
        assert!(math::test_constant_product_invariant(500000, 1500000, 25000), 2);
    }

    #[test]
    fun test_k_invariant_validation() {
        let old_a = 1000000;
        let old_b = 2000000;
        let old_k = math::get_k_value(old_a, old_b);
        
        // Test that equal reserves maintain invariant
        assert!(math::validate_k_invariant(old_a, old_b, old_a, old_b), 1);
        
        // Test that slightly higher k is acceptable
        let new_a = 1000001;
        let new_b = 2000000;
        assert!(math::validate_k_invariant(old_a, old_b, new_a, new_b), 2);
    }

    #[test]
    fun test_price_impact_calculation() {
        let reserve_in = 1000000;
        let reserve_out = 1000000; // Equal reserves for simplicity
        
        // Small trade should have minimal price impact
        let small_amount = 1000; // 0.1% of reserves
        let small_impact = math::calculate_price_impact(reserve_in, reserve_out, small_amount);
        assert!(small_impact < 100, 1); // Less than 1% impact
        
        // Large trade should have significant price impact
        let large_amount = 100000; // 10% of reserves
        let large_impact = math::calculate_price_impact(reserve_in, reserve_out, large_amount);
        assert!(large_impact > small_impact, 2);
        assert!(large_impact > 500, 3); // More than 5% impact
    }

    #[test]
    fun test_swap_with_fee() {
        let reserve_in = 1000000;
        let reserve_out = 1000000;
        let amount_in = 10000;
        
        // Test with 0% fee (should equal regular swap)
        let no_fee_output = math::calculate_swap_output_with_fee(reserve_in, reserve_out, amount_in, 0);
        let regular_output = math::calculate_swap_output(reserve_in, reserve_out, amount_in);
        assert!(no_fee_output == regular_output, 1);
        
        // Test with 0.3% fee (30 basis points)
        let fee_output = math::calculate_swap_output_with_fee(reserve_in, reserve_out, amount_in, 30);
        assert!(fee_output < regular_output, 2); // Fee should reduce output
        
        // Test with 1% fee (100 basis points)
        let higher_fee_output = math::calculate_swap_output_with_fee(reserve_in, reserve_out, amount_in, 100);
        assert!(higher_fee_output < fee_output, 3); // Higher fee should reduce output more
    }

    #[test]
    fun test_liquidity_calculations() {
        // Test initial liquidity (total_supply = 0)
        let apt_amount = 1000000;
        let usdc_amount = 2000000;
        let initial_lp = math::calculate_liquidity_amounts(apt_amount, usdc_amount, 0, 0, 0);
        
        let expected_initial = math::sqrt(apt_amount * usdc_amount) - MIN_LIQUIDITY;
        assert!(initial_lp == expected_initial, 1);
        
        // Test subsequent liquidity
        let apt_reserve = 1000000;
        let usdc_reserve = 2000000;
        let total_supply = 1000000;
        
        let subsequent_lp = math::calculate_liquidity_amounts(
            apt_amount / 2, // Half the amounts
            usdc_amount / 2,
            apt_reserve,
            usdc_reserve,
            total_supply
        );
        
        // Should get half the LP tokens
        assert!(subsequent_lp == total_supply / 2, 2);
    }

    #[test]
    fun test_optimal_liquidity_calculation() {
        let apt_reserve = 1000000;
        let usdc_reserve = 2000000; // 2:1 ratio
        
        // Test when APT is limiting factor
        let desired_apt = 100000;
        let desired_usdc = 300000; // More than 2:1 ratio
        
        let (optimal_apt, optimal_usdc) = math::calculate_optimal_liquidity(
            desired_apt, desired_usdc, apt_reserve, usdc_reserve
        );
        
        assert!(optimal_apt == desired_apt, 1);
        assert!(optimal_usdc == 200000, 2); // Should be 2:1 ratio
        
        // Test when USDC is limiting factor
        let desired_apt2 = 200000;
        let desired_usdc2 = 100000; // Less than 2:1 ratio
        
        let (optimal_apt2, optimal_usdc2) = math::calculate_optimal_liquidity(
            desired_apt2, desired_usdc2, apt_reserve, usdc_reserve
        );
        
        assert!(optimal_usdc2 == desired_usdc2, 3);
        assert!(optimal_apt2 == 50000, 4); // Should be 1:2 ratio
    }

    #[test]
    fun test_withdrawal_calculations() {
        let apt_reserve = 1000000;
        let usdc_reserve = 2000000;
        let total_supply = 1000000;
        let lp_amount = 100000; // 10% of total supply
        
        let (apt_out, usdc_out) = math::calculate_withdrawal_amounts(
            lp_amount, apt_reserve, usdc_reserve, total_supply
        );
        
        // Should get 10% of each reserve
        assert!(apt_out == 100000, 1);
        assert!(usdc_out == 200000, 2);
    }

    #[test]
    fun test_slippage_protection() {
        let expected = 1000000;
        let tolerance = 500; // 5% tolerance
        
        // Test within tolerance
        assert!(math::check_slippage(expected, 950000, tolerance), 1); // 5% below
        assert!(math::check_slippage(expected, 1050000, tolerance), 2); // 5% above
        assert!(math::check_slippage(expected, expected, tolerance), 3); // Exact
        
        // Test outside tolerance
        assert!(!math::check_slippage(expected, 940000, tolerance), 4); // 6% below
        assert!(!math::check_slippage(expected, 1060000, tolerance), 5); // 6% above
    }

    #[test]
    fun test_percentage_calculation() {
        let value = 1000000;
        
        // Test 1% (100 basis points)
        assert!(math::calculate_percentage(value, 100) == 10000, 1);
        
        // Test 0.5% (50 basis points)
        assert!(math::calculate_percentage(value, 50) == 5000, 2);
        
        // Test 10% (1000 basis points)
        assert!(math::calculate_percentage(value, 1000) == 100000, 3);
        
        // Test 0% (0 basis points)
        assert!(math::calculate_percentage(value, 0) == 0, 4);
    }

    #[test]
    fun test_approximately_equal() {
        let a = 1000000;
        let b = 1005000; // 0.5% difference
        let tolerance = 100; // 1% tolerance
        
        assert!(math::approximately_equal(a, b, tolerance), 1);
        
        let c = 1020000; // 2% difference
        assert!(!math::approximately_equal(a, c, tolerance), 2);
    }

    #[test]
    #[expected_failure(abort_code = 31)] // division by zero
    fun test_swap_zero_reserves() {
        math::calculate_swap_output(0, 1000000, 1000);
    }

    #[test]
    #[expected_failure(abort_code = 21)] // insufficient input
    fun test_swap_zero_input() {
        math::calculate_swap_output(1000000, 1000000, 0);
    }

    #[test]
    #[expected_failure(abort_code = 31)] // division by zero
    fun test_liquidity_zero_reserves() {
        math::calculate_liquidity_amounts(1000, 1000, 0, 1000, 1000);
    }

    #[test]
    fun test_constants() {
        assert!(math::get_precision_factor() == PRECISION_FACTOR, 1);
        assert!(math::get_min_liquidity() == MIN_LIQUIDITY, 2);
        assert!(math::get_max_slippage_bps() == 10000, 3);
    }
} 