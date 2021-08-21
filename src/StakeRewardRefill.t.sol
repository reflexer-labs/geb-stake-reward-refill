pragma solidity ^0.6.7;

import "ds-test/test.sol";
import "ds-token/delegate.sol";

import "./StakeRewardRefill.sol";

abstract contract Hevm {
    function warp(uint256) virtual public;
}

contract User {
    function transferTokenOut(StakeRewardRefill refill, address dst, uint256 amount) external {
        refill.transferTokenOut(dst, amount);
    }
    function refill(StakeRewardRefill refill) external {
        refill.refill();
    }
}

contract StakeRewardRefillTest is DSTest {
    Hevm hevm;

    DSDelegateToken   rewardToken;
    StakeRewardRefill refill;
    User              usr;

    uint256 openRefill   = 0;
    uint256 refillDelay  = 24 hours;
    uint256 refillAmount = 5 ether;

    uint256 amountToMint = 100 ether;
    uint256 startTime    = 1577836800;

    address alice = address(0x123);

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(startTime);

        usr = new User();

        rewardToken = new DSDelegateToken("UNGOV", "UNGOV");
        rewardToken.mint(address(this), amountToMint);

        refill      = new StakeRewardRefill(
          address(rewardToken),
          alice,
          openRefill,
          refillDelay,
          refillAmount
        );
        rewardToken.transfer(address(refill), amountToMint);
    }

    function test_setup() public {
        assertEq(refill.authorizedAccounts(address(this)), 1);
        assertEq(refill.lastRefillTime(), now);
        assertEq(refill.refillDelay(), refillDelay);
        assertEq(refill.refillAmount(), refillAmount);
        assertEq(refill.openRefill(), openRefill);

        assertEq(refill.refillDestination(), alice);
        assertEq(address(refill.rewardToken()), address(rewardToken));
    }
    function test_modify_parameters() public {
        hevm.warp(now + 1 hours);

        refill.modifyParameters("refillDestination", address(0x987));
        refill.modifyParameters("openRefill", 1);
        refill.modifyParameters("lastRefillTime", now - 1);
        refill.modifyParameters("refillDelay", 48 hours);
        refill.modifyParameters("refillAmount", 10);

        assertEq(refill.authorizedAccounts(address(this)), 1);
        assertEq(refill.lastRefillTime(), now - 1);
        assertEq(refill.refillDelay(), 48 hours);
        assertEq(refill.refillAmount(), 10);
        assertEq(refill.openRefill(), 1);

        assertEq(refill.refillDestination(), address(0x987));
        assertEq(address(refill.rewardToken()), address(rewardToken));
    }
    function test_transfer_token_out() public {
        uint256 refillerBalance = rewardToken.balanceOf(address(refill));
        refill.transferTokenOut(address(0x987), 1 ether);

        assertEq(rewardToken.balanceOf(address(refill)), refillerBalance - 1 ether);
        assertEq(rewardToken.balanceOf(address(0x987)), 1 ether);
    }
    function testFail_transfer_token_out_random_caller() public {
        uint256 refillerBalance = rewardToken.balanceOf(address(refill));
        usr.transferTokenOut(refill, address(0x987), 1 ether);
    }
    function testFail_transfer_token_out_null_dst() public {
        uint256 refillerBalance = rewardToken.balanceOf(address(refill));
        refill.transferTokenOut(address(0x987), 0);
    }
    function testFail_transfer_token_out_null_amount() public {
        uint256 refillerBalance = rewardToken.balanceOf(address(refill));
        refill.transferTokenOut(address(0), 1 ether);
    }
    function test_refill() public {
        hevm.warp(now + refillDelay);

        uint256 refillerBalance = rewardToken.balanceOf(address(refill));
        refill.refill();

        assertEq(refill.lastRefillTime(), now);
        assertEq(rewardToken.balanceOf(address(refill)), refillerBalance - refillAmount);
        assertEq(rewardToken.balanceOf(alice), refillAmount);
    }
    function test_refill_uneven_slot() public {
        hevm.warp(now + refillDelay + 5);

        uint256 refillerBalance = rewardToken.balanceOf(address(refill));
        refill.refill();

        assertEq(refill.lastRefillTime(), now - 5);
        assertEq(rewardToken.balanceOf(address(refill)), refillerBalance - refillAmount);
        assertEq(rewardToken.balanceOf(alice), refillAmount);
    }
    function test_refill_multiple_times_at_once() public {
        hevm.warp(now + refillDelay * 5);

        uint256 refillerBalance = rewardToken.balanceOf(address(refill));
        refill.refill();

        assertEq(refill.lastRefillTime(), now);
        assertEq(rewardToken.balanceOf(address(refill)), refillerBalance - refillAmount * 5);
        assertEq(rewardToken.balanceOf(alice), refillAmount * 5);
    }
    function test_refill_multiple_times_at_once_uneven_slot() public {
        hevm.warp(now + refillDelay * 5 + 10);

        uint256 refillerBalance = rewardToken.balanceOf(address(refill));
        refill.refill();

        assertEq(refill.lastRefillTime(), now - 10);
        assertEq(rewardToken.balanceOf(address(refill)), refillerBalance - refillAmount * 5);
        assertEq(rewardToken.balanceOf(alice), refillAmount * 5);
    }
    function testFail_refill_wait_more() public {
        hevm.warp(now + refillDelay - 1);
        refill.refill();
    }
    function testFail_refill_not_enough_balance() public {
        refill.transferTokenOut(address(0x987), rewardToken.balanceOf(address(refill)) - refillAmount + 1);

        hevm.warp(now + refillDelay - 1);
        refill.refill();
    }
}
