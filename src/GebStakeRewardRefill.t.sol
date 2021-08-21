pragma solidity ^0.6.7;

import "ds-test/test.sol";

import "./GebStakeRewardRefill.sol";

contract GebStakeRewardRefillTest is DSTest {
    GebStakeRewardRefill refill;

    function setUp() public {
        refill = new GebStakeRewardRefill();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
