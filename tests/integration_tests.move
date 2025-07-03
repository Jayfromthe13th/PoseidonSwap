#[test_only]
module poseidon_swap::integration_tests {
    use poseidon_swap::math;
    use poseidon_swap::errors;
    use poseidon_swap::events;

    #[test]
    fun test_math_error_integration() {
        // Test that math functions properly use error codes from errors module
        
        // Test division by zero error
        let error_code = errors::division_by_zero();
        assert!(error_code == 31, 1);
        
        // Test overflow error
        let overflow_code = errors::overflow();
        assert!(overflow_code == 30, 2);
        
        // Test insufficient input error
        let input_error = errors::insufficient_input_amount();
        assert!(input_error == 21, 3);
    }

    #[test]
    #[expected_failure(abort_code = 31, location = poseidon_swap::math)]
    fun test_math_error_propagation_division_by_zero() {
        // This should fail with the correct error code from errors module
        math::calculate_swap_output(0, 1000000, 1000);
    }

    #[test]
    #[expected_failure(abort_code = 21, location = poseidon_swap::math)]
    fun test_math_error_propagation_insufficient_input() {
        // This should fail with the correct error code from errors module
        math::calculate_swap_output(1000000, 1000000, 0);
    }

    #[test]
    #[expected_failure(abort_code = 30, location = poseidon_swap::math)]
    fun test_math_error_propagation_overflow() {
        // This should fail with the correct error code from errors module
        math::multiply_u64(18446744073709551615, 2);
    }

    #[test]
    fun test_math_constants_consistency() {
        // Test that math module constants are consistent and accessible
        let precision = math::get_precision_factor();
        let min_liquidity = math::get_min_liquidity();
        let max_slippage = math::get_max_slippage_bps();
        
        assert!(precision == 1000000, 1); // 6 decimal places
        assert!(min_liquidity == 1000, 2); // Minimum liquidity
        assert!(max_slippage == 10000, 3); // 100% in basis points
        
        // Test that constants are used correctly in calculations
        let percentage = math::calculate_percentage(1000000, 100); // 1%
        assert!(percentage == 10000, 4);
    }

    #[test]
    fun test_math_view_functions_integration() {
        // Test that all view functions work correctly and return expected values
        let reserve_in = 1000000;
        let reserve_out = 2000000;
        let amount_in = 100000;
        
        // Test quote_swap
        let quote = math::quote_swap(reserve_in, reserve_out, amount_in);
        let direct = math::calculate_swap_output(reserve_in, reserve_out, amount_in);
        assert!(quote == direct, 1);
        
        // Test quote_swap_with_fee
        let quote_fee = math::quote_swap_with_fee(reserve_in, reserve_out, amount_in, 30);
        let direct_fee = math::calculate_swap_output_with_fee(reserve_in, reserve_out, amount_in, 30);
        assert!(quote_fee == direct_fee, 2);
        
        // Test quote_price_impact
        let impact = math::quote_price_impact(reserve_in, reserve_out, amount_in);
        let direct_impact = math::calculate_price_impact(reserve_in, reserve_out, amount_in);
        assert!(impact == direct_impact, 3);
        
        // Test quote_liquidity
        let lp_quote = math::quote_liquidity(100000, 200000, reserve_in, reserve_out, 1000000);
        let lp_direct = math::calculate_liquidity_amounts(100000, 200000, reserve_in, reserve_out, 1000000);
        assert!(lp_quote == lp_direct, 4);
        
        // Test quote_optimal_liquidity
        let (opt_umi, opt_shell) = math::quote_optimal_liquidity(150000, 250000, reserve_in, reserve_out);
        let (direct_umi, direct_shell) = math::calculate_optimal_liquidity(150000, 250000, reserve_in, reserve_out);
        assert!(opt_umi == direct_umi && opt_shell == direct_shell, 5);
    }

    #[test]
    fun test_math_precision_consistency() {
        // Test that precision is maintained across different operations
        let value = 1000000;
        let _precision = math::get_precision_factor();
        
        // Test percentage calculations maintain precision
        let one_percent = math::calculate_percentage(value, 100);
        assert!(one_percent == value / 100, 1);
        
        let half_percent = math::calculate_percentage(value, 50);
        assert!(half_percent == value / 200, 2);
        
        // Test slippage calculations
        assert!(math::check_slippage(value, value, 0), 3); // Exact match
        assert!(math::check_slippage(value, value - one_percent, 100), 4); // 1% tolerance
        assert!(!math::check_slippage(value, value - one_percent * 2, 100), 5); // Outside tolerance
    }

    #[test]
    fun test_math_edge_cases_comprehensive() {
        // Test comprehensive edge cases that might occur in real usage
        
        // Very small amounts (but not too small to cause division issues)
        let small_reserve = 10000; // Increased from 1000
        let small_amount = 100; // Increased from 1
        let small_output = math::calculate_swap_output(small_reserve, small_reserve, small_amount);
        assert!(small_output > 0, 1);
        
        // Large amounts (but not overflow)
        let large_reserve = 1000000000; // 1B
        let large_amount = 1000000; // 1M
        let large_output = math::calculate_swap_output(large_reserve, large_reserve, large_amount);
        assert!(large_output > 0 && large_output < large_amount, 2);
        
        // Asymmetric reserves
        let small_res = 100000;
        let large_res = 10000000;
        let asym_output = math::calculate_swap_output(small_res, large_res, 1000);
        assert!(asym_output > 0, 3);
        
        // Test minimum liquidity enforcement
        let min_liq = math::get_min_liquidity();
        let initial_lp = math::calculate_liquidity_amounts(100000, 100000, 0, 0, 0); // Increased amounts
        let expected = math::sqrt(100000 * 100000) - min_liq;
        assert!(initial_lp == expected, 4);
    }

    #[test]
    fun test_math_invariant_preservation() {
        // Test that mathematical invariants are preserved across operations
        let reserve_a = 1000000;
        let reserve_b = 2000000;
        let amount_in = 50000;
        
        // Test constant product invariant
        let _k_before = math::get_k_value(reserve_a, reserve_b);
        let amount_out = math::calculate_swap_output(reserve_a, reserve_b, amount_in);
        let new_reserve_a = reserve_a + amount_in;
        let new_reserve_b = reserve_b - amount_out;
        let _k_after = math::get_k_value(new_reserve_a, new_reserve_b);
        
        // K should be preserved (allowing for rounding)
        assert!(math::validate_k_invariant(reserve_a, reserve_b, new_reserve_a, new_reserve_b), 1);
        
        // Test that price impact is reasonable
        let price_impact = math::calculate_price_impact(reserve_a, reserve_b, amount_in);
        assert!(price_impact > 0, 2); // Should have some impact
        assert!(price_impact < 10000, 3); // Should not be 100%+
    }

    #[test]
    fun test_math_fee_calculations() {
        // Test fee calculations work correctly
        let reserve_in = 1000000;
        let reserve_out = 1000000;
        let amount_in = 10000;
        
        // No fee should equal regular swap
        let no_fee = math::calculate_swap_output_with_fee(reserve_in, reserve_out, amount_in, 0);
        let regular = math::calculate_swap_output(reserve_in, reserve_out, amount_in);
        assert!(no_fee == regular, 1);
        
        // Fee should reduce output
        let with_fee = math::calculate_swap_output_with_fee(reserve_in, reserve_out, amount_in, 30);
        assert!(with_fee < regular, 2);
        
        // Higher fee should reduce output more
        let higher_fee = math::calculate_swap_output_with_fee(reserve_in, reserve_out, amount_in, 100);
        assert!(higher_fee < with_fee, 3);
        
        // Test fee bounds
        let max_slippage = math::get_max_slippage_bps();
        let max_fee = math::calculate_swap_output_with_fee(reserve_in, reserve_out, amount_in, max_slippage);
        assert!(max_fee == 0, 4); // 100% fee should result in 0 output
    }

    #[test]
    fun test_math_liquidity_edge_cases() {
        // Test liquidity calculations with edge cases
        
        // Test with amounts that will satisfy minimum liquidity requirements
        let min_umi = 10000; // Increased from 1000
        let min_shell = 10000; // Increased from 1000
        let min_lp = math::calculate_liquidity_amounts(min_umi, min_shell, 0, 0, 0);
        assert!(min_lp > 0, 1);
        
        // Test proportional liquidity
        let umi_reserve = 1000000;
        let shell_reserve = 2000000;
        let total_supply = 1000000;
        
        // Adding same ratio should give proportional LP tokens
        let prop_lp = math::calculate_liquidity_amounts(
            umi_reserve / 10, // 10% of reserve
            shell_reserve / 10, // 10% of reserve
            umi_reserve,
            shell_reserve,
            total_supply
        );
        assert!(prop_lp == total_supply / 10, 2); // Should get 10% of LP tokens
        
        // Test optimal liquidity calculation
        let (opt_umi, opt_shell) = math::calculate_optimal_liquidity(
            150000, // Want more UMI than ratio
            200000, // Want less Shell than ratio
            umi_reserve,
            shell_reserve
        );
        
        // Should maintain 1:2 ratio
        assert!(opt_shell == opt_umi * 2, 3);
    }

    #[test]
    fun test_events_module_accessibility() {
        // Test that events module functions are accessible (integration test)
        // This verifies the module structure is correct for integration
        
        // Test that we can call event emission functions without errors
        // (In a real scenario, these would be called by the pool module)
        events::emit_pool_created(
            @0x1,
            1000000,
            2000000,
            1000000,
            @0x2
        );
        
        events::emit_swap_executed(
            @0x1,
            @0x2,
            10000,
            0,
            0,
            19000,
            1010000,
            1981000
        );
        
        // If we reach here, the integration is working
        assert!(true, 1);
    }

    #[test]
    fun test_comprehensive_amm_simulation() {
        // Comprehensive test simulating real AMM operations
        let initial_umi = 1000000;
        let initial_shell = 2000000;
        let initial_lp_supply = 0;
        
        // Step 1: Initial liquidity provision
        let initial_lp = math::calculate_liquidity_amounts(
            initial_umi,
            initial_shell,
            0,
            0,
            initial_lp_supply
        );
        assert!(initial_lp > 0, 1);
        
        // Step 2: Simulate a swap
        let swap_amount = 50000; // 5% of UMI reserve
        let shell_out = math::calculate_swap_output(initial_umi, initial_shell, swap_amount);
        assert!(shell_out > 0, 2);
        
        // Step 3: Check price impact
        let price_impact = math::calculate_price_impact(initial_umi, initial_shell, swap_amount);
        assert!(price_impact > 0 && price_impact < 1000, 3); // Between 0% and 10%
        
        // Step 4: Update reserves after swap
        let new_umi_reserve = initial_umi + swap_amount;
        let new_shell_reserve = initial_shell - shell_out;
        
        // Step 5: Verify invariant
        assert!(math::validate_k_invariant(
            initial_umi,
            initial_shell,
            new_umi_reserve,
            new_shell_reserve
        ), 4);
        
        // Step 6: Add more liquidity
        let additional_umi = 100000;
        let additional_shell = 200000;
        let additional_lp = math::calculate_liquidity_amounts(
            additional_umi,
            additional_shell,
            new_umi_reserve,
            new_shell_reserve,
            initial_lp
        );
        assert!(additional_lp > 0, 5);
        
        // Step 7: Test withdrawal
        let withdraw_lp = additional_lp / 2; // Withdraw half
        let (umi_out, shell_out_withdraw) = math::calculate_withdrawal_amounts(
            withdraw_lp,
            new_umi_reserve + additional_umi,
            new_shell_reserve + additional_shell,
            initial_lp + additional_lp
        );
        assert!(umi_out > 0 && shell_out_withdraw > 0, 6);
        
        // All operations completed successfully
        assert!(true, 7);
    }
} 