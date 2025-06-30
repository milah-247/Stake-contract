// test/EthStaking.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/stake.sol";
import "../src/erc20.sol";

/// @dev Simple ERC20 for reward tokens
contract RewardToken is ERC20 {
    constructor() ERC20("Reward", "RWD") {
        _mint(msg.sender, 1e24); // mint plenty
    }
}

contract EthStakingTest is Test {
    EthStaking staking;
    RewardToken rewardToken;
    address user = address(1);

    uint256 constant REWARD_RATE = 1e18; // 1 token per ETH per sec (scaled)
    uint256 constant LOCK_PERIOD = 1 hours;

    function setUp() public {
        rewardToken = new RewardToken();
        staking = new EthStaking(address(rewardToken), REWARD_RATE, LOCK_PERIOD);

        // Fund the reward pool
        rewardToken.approve(address(staking), 1e24);
        staking.fundRewards(1e24);
    }

    function testStakeAndClaim() public {
        vm.deal(user, 5 ether);
        vm.prank(user);
        staking.stake{value: 2 ether}();

        // Move forward past lock period
        vm.warp(block.timestamp + LOCK_PERIOD + 10);

        uint256 startBal = rewardToken.balanceOf(user);

        vm.prank(user);
        staking.claim();

        // Check principals and reward received
        assertEq(rewardToken.balanceOf(user), startBal + (2 ether * REWARD_RATE * (LOCK_PERIOD + 10) / 1e18));
        assertEq(address(staking).balance, 0); // all ETH returned
    }

    function testCannotClaimEarly() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        staking.stake{value: 1 ether}();

        vm.expectRevert("Lock period not over");
        vm.prank(user);
        staking.claim();
    }

    function testFuzz_StakeAmount(uint256 stakeAmt, uint256 dt) public {
        vm.assume(stakeAmt > 0 && stakeAmt <= 3 ether);
        vm.assume(dt >= LOCK_PERIOD && dt <= LOCK_PERIOD + 1 days);

        vm.deal(user, stakeAmt);
        vm.prank(user);
        staking.stake{value: stakeAmt}();

        vm.warp(block.timestamp + dt);

        vm.prank(user);
        staking.claim();

        // reward formula
        uint256 expectedReward = stakeAmt * REWARD_RATE * dt / 1e18;
        assertEq(rewardToken.balanceOf(user), expectedReward);
    }
}
