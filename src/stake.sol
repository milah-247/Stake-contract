// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EthStaking {
    address public owner;
    IERC20  public rewardToken;
    uint256 public rewardRatePerSecond; 
    uint256 public lockPeriod;           

    struct StakeInfo {
        uint256 amount;
        uint256 start;
        bool claimed;
    }

    mapping(address => StakeInfo) public stakes;

    event Staked(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 reward);

    constructor(address _rewardToken, uint256 _rewardRatePerSecond, uint256 _lockPeriod) {
        rewardToken = IERC20(_rewardToken);
        rewardRatePerSecond = _rewardRatePerSecond;
        lockPeriod = _lockPeriod;
    }

    function stake() external payable nonReentrant {
        require(msg.value > 0, "Must send ETH");
        StakeInfo storage s = stakes[msg.sender];
        require(s.amount == 0 || s.claimed, "Already active stake");

        s.amount = msg.value;
        s.start = block.timestamp;
        s.claimed = false;

        emit Staked(msg.sender, msg.value);
    }

    function claim() external nonReentrant {
        StakeInfo storage s = stakes[msg.sender];
        require(s.amount > 0 && !s.claimed, "No stake");
        require(block.timestamp >= s.start + lockPeriod, "Lock not ended");

        uint256 duration = block.timestamp - s.start;
        uint256 reward = s.amount * rewardRatePerSecond * duration / 1e18;

        uint256 principal = s.amount;
        s.claimed = true;
        s.amount = 0;

        payable(msg.sender).transfer(principal);
        require(rewardToken.transfer(msg.sender, reward), "Reward failed");

        emit Claimed(msg.sender, reward);
    }

    // Optional: allow owner to top-up reward pool
    function fundRewards(uint256 amount) external {
        rewardToken.transferFrom(msg.sender, address(this), amount);
    }
}
