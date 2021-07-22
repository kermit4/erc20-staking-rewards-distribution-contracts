// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IERC20StakingRewardsDistributionFactory.sol";

/**
 * Errors codes:
 *
 * SRD01: invalid starting timestamp
 * SRD02: invalid time duration
 * SRD03: inconsistent reward token/amount
 * SRD04: 0 address as reward token
 * SRD05: no reward
 * SRD06: no funding
 * SRD07: 0 address as stakable token
 * SRD08: distribution already started
 * SRD09: tried to stake nothing
 * SRD10: staking cap hit
 * SRD11: tried to withdraw nothing
 * SRD12: funds locked until the distribution ends
 * SRD13: withdrawn amount greater than current stake
 * SRD14: inconsistent claimed amounts
 * SRD15: insufficient claimable amount
 * SRD16: 0 address owner
 * SRD17: caller not owner
 * SRD18: already initialized
 * SRD19: invalid state for cancel to be called
 * SRD20: not started
 * SRD21: already ended
 * SRD22: no rewards are recoverable
 * SRD23: no rewards are claimable while claiming all
 * SRD24: no rewards are claimable while manually claiming an arbitrary amount of rewards
 * SRD25: staking is currently paused
 */
contract ERC20StakingRewardsDistribution {
    using SafeERC20 for IERC20;

    uint256 public constant MULTIPLIER = 2**64;

    struct Reward {
        address token;
        uint256 amount;
        uint256 unassigned;
        uint256 perStakedToken;
    }

    struct StakerRewardInfo {
        uint256 consolidatedPerStakedToken;
        uint256 earned;
        uint256 claimed;
    }

    struct Staker {
        uint256 stake;
        mapping(address => StakerRewardInfo) rewardInfo;
    }

    Reward[] public rewards;
    mapping(address => Staker) public stakers;
    uint64 public startingTimestamp;
    uint64 public endingTimestamp;
    uint64 public secondsDuration;
    uint64 public lastConsolidationTimestamp;
    IERC20 public stakableToken;
    address public owner;
    address public factory;
    bool public locked;
    bool public canceled;
    bool public initialized;
    uint256 public totalStakedTokensAmount;
    uint256 public stakingCap;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event Initialized(
        address[] rewardsTokenAddresses,
        address stakableTokenAddress,
        uint256[] rewardsAmounts,
        uint64 startingTimestamp,
        uint64 endingTimestamp,
        bool locked,
        uint256 stakingCap
    );
    event Canceled();
    event Staked(address indexed staker, uint256 amount);
    event Withdrawn(address indexed withdrawer, uint256 amount);
    event Claimed(address indexed claimer, uint256[] amounts);
    event Recovered(uint256[] amounts);
    event UpdatedRewards(uint256[] amounts);

    function initialize(
        address[] calldata _rewardTokenAddresses,
        address _stakableTokenAddress,
        uint256[] calldata _rewardAmounts,
        uint64 _startingTimestamp,
        uint64 _endingTimestamp,
        bool _locked,
        uint256 _stakingCap
    ) external onlyUninitialized {
        require(_endingTimestamp > _startingTimestamp, "SRD02");
        require(_rewardTokenAddresses.length == _rewardAmounts.length, "SRD03");

        secondsDuration = _endingTimestamp - _startingTimestamp;
        // Initializing reward tokens and amounts
        for (uint32 _i = 0; _i < _rewardTokenAddresses.length; _i++) {
            address _rewardTokenAddress = _rewardTokenAddresses[_i];
            uint256 _rewardAmount = _rewardAmounts[_i];
            require(_rewardTokenAddress != address(0), "SRD04");
            IERC20 _rewardToken = IERC20(_rewardTokenAddress);
            require(
                _rewardToken.balanceOf(address(this)) == _rewardAmount,
                "SRD06"
            );
            rewards.push(
                Reward({
                    token: _rewardTokenAddress,
                    amount: _rewardAmount,
                    unassigned: _rewardAmount * MULTIPLIER,
                    perStakedToken: 0,
                })
            );
        }

        require(_stakableTokenAddress != address(0), "SRD07");
        stakableToken = IERC20(_stakableTokenAddress);

        owner = msg.sender;
        factory = msg.sender;
        startingTimestamp = _startingTimestamp;
        endingTimestamp = _endingTimestamp;
        lastConsolidationTimestamp = _startingTimestamp;
        locked = _locked;
        stakingCap = _stakingCap;
        initialized = true;
        canceled = false;

        emit Initialized(
            _rewardTokenAddresses,
            _stakableTokenAddress,
            _rewardAmounts,
            _startingTimestamp,
            _endingTimestamp,
            _locked,
            _stakingCap
        );
    }

    function cancel() external onlyOwner {
        require(initialized && !canceled, "SRD19");
        require(block.timestamp < startingTimestamp, "SRD08");
        for (uint256 _i; _i < rewards.length; _i++) {
            Reward storage _reward = rewards[_i];
            IERC20(_reward.token).safeTransfer(
                owner,
                IERC20(_reward.token).balanceOf(address(this))
            );
        }
        canceled = true;
        emit Canceled();
    }

    function recoverUnassignedRewards() external onlyStarted {
        consolidateReward();
        uint256[] memory _recoveredUnassignedRewards =
            new uint256[](rewards.length);
        require(block.timestamp >= endingTimestamp, "SRD12");
        bool _atLeastOneNonZeroRecovery = false;
        for (uint256 _i; _i < rewards.length; _i++) {
            Reward storage _reward = rewards[_i];
            // recoverable rewards are going to be recovered in this tx (if it does not revert),
            if (_reward.unassigned == 0) continue;
            _atLeastOneNonZeroRecovery = true;
            _recoveredUnassignedRewards[_i] = _reward.unassigned / MULTIPLIER;
            IERC20(_reward.token).safeTransfer(
                owner,
                _reward.unassigned / MULTIPLIER
            );
            _reward.unassigned = 0;
        }
        require(_atLeastOneNonZeroRecovery, "SRD22");
        emit Recovered(_recoveredUnassignedRewards);
    }

    function stake(uint256 _amount) external onlyRunning {
        require(
            !IERC20StakingRewardsDistributionFactory(factory).stakingPaused(),
            "SRD25"
        );
        require(_amount > 0, "SRD09");
        if (stakingCap > 0) {
            require(totalStakedTokensAmount + _amount <= stakingCap, "SRD10");
        }
        consolidateReward();
        Staker storage _staker = stakers[msg.sender];
        _staker.stake += _amount;
        totalStakedTokensAmount += _amount;
        stakableToken.safeTransferFrom(msg.sender, address(this), _amount);
        emit Staked(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) public onlyStarted {
        require(_amount > 0, "SRD11");
        if (locked) {
            require(block.timestamp > endingTimestamp, "SRD12");
        }
        consolidateReward();
        Staker storage _staker = stakers[msg.sender];
        require(_staker.stake >= _amount, "SRD13");
        _staker.stake -= _amount;
        totalStakedTokensAmount -= _amount;
        stakableToken.safeTransfer(msg.sender, _amount);
        emit Withdrawn(msg.sender, _amount);
    }

    function claim(uint256[] memory _amounts, address _recipient)
        external
        onlyStarted
    {
        require(_amounts.length == rewards.length, "SRD14");
        consolidateReward();
        Staker storage _staker = stakers[msg.sender];
        uint256[] memory _claimedRewards = new uint256[](rewards.length);
        bool _atLeastOneNonZeroClaim = false;
        for (uint256 _i; _i < rewards.length; _i++) {
            Reward storage _reward = rewards[_i];
            StakerRewardInfo storage _stakerRewardInfo =
                _staker.rewardInfo[_reward.token];
            uint256 _claimableReward =
                _stakerRewardInfo.earned - _stakerRewardInfo.claimed;
            uint256 _wantedAmount = _amounts[_i];
            require(_claimableReward >= _wantedAmount, "SRD15");
            if (!_atLeastOneNonZeroClaim && _wantedAmount > 0)
                _atLeastOneNonZeroClaim = true;
            _stakerRewardInfo.claimed += _wantedAmount;
            IERC20(_reward.token).safeTransfer(_recipient, _wantedAmount);
            _claimedRewards[_i] = _wantedAmount;
        }
        require(_atLeastOneNonZeroClaim, "SRD24");
        emit Claimed(msg.sender, _claimedRewards);
    }

    function claimAll(address _recipient) public onlyStarted {
        consolidateReward();
        Staker storage _staker = stakers[msg.sender];
        uint256[] memory _claimedRewards = new uint256[](rewards.length);
        bool _atLeastOneNonZeroClaim = false;
        for (uint256 _i; _i < rewards.length; _i++) {
            Reward storage _reward = rewards[_i];
            StakerRewardInfo storage _stakerRewardInfo =
                _staker.rewardInfo[_reward.token];
            uint256 _claimableReward =
                _stakerRewardInfo.earned - _stakerRewardInfo.claimed;
            if (_claimableReward == 0) continue;
            _atLeastOneNonZeroClaim = true;
            _stakerRewardInfo.claimed += _claimableReward;

            IERC20(_reward.token).safeTransfer(_recipient, _claimableReward);
            _claimedRewards[_i] = _claimableReward;
        }
        require(_atLeastOneNonZeroClaim, "SRD23");
        emit Claimed(msg.sender, _claimedRewards);
    }

    function exit(address _recipient) external onlyStarted {
        claimAll(_recipient);
        withdraw(stakers[msg.sender].stake);
    }

    function consolidateReward() private {
        uint64 _consolidationTimestamp =
            uint64(Math.min(block.timestamp, endingTimestamp));
        uint256 _lastPeriodDuration =
            uint256(_consolidationTimestamp - lastConsolidationTimestamp);
        uint256 _unconsolidatedDuration =
            uint256(endingTimestamp - lastConsolidationTimestamp);
        Staker storage _staker = stakers[msg.sender];
        lastConsolidationTimestamp = _consolidationTimestamp;
        for (uint256 _i; _i < rewards.length; _i++) {
            Reward storage _reward = rewards[_i];
            StakerRewardInfo storage _stakerRewardInfo =
                _staker.rewardInfo[_reward.token];
            uint256 _thisPerStakedToken;
            if (_unconsolidatedDuration * totalStakedTokensAmount > 0) {
                _thisPerStakedToken =
                    (_lastPeriodDuration * _reward.unassigned) /
                    totalStakedTokensAmount /
                    _unconsolidatedDuration;
                _reward.perStakedToken += _thisPerStakedToken;
            }
            _reward.unassigned -= (_thisPerStakedToken *
                totalStakedTokensAmount);

            _stakerRewardInfo.earned +=
                (_staker.stake *
                    (_reward.perStakedToken -
                        _stakerRewardInfo.consolidatedPerStakedToken)) /
                MULTIPLIER;
            _stakerRewardInfo.consolidatedPerStakedToken = _reward
                .perStakedToken;
        }
    }

    function addRewards(address _token, uint256 _amount) public {
        consolidateReward();
        uint256[] memory _updatedAmounts = new uint256[](rewards.length);
        for (uint32 _i = 0; _i < rewards.length; _i++) {
            address _rewardTokenAddress = rewards[_i].token;
            if (_rewardTokenAddress == _token) {
                IERC20(_token).safeTransferFrom(
                    msg.sender,
                    address(this),
                    _amount
                );
                rewards[_i].amount += _amount;
                rewards[_i].unassigned += _amount * MULTIPLIER;
            }
            _updatedAmounts[_i] = rewards[_i].amount;
        }
        emit UpdatedRewards(_updatedAmounts);
    }

    function claimableRewards(address _account)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory _outstandingRewards = new uint256[](rewards.length);
        if (!initialized) return _outstandingRewards;
        if (block.timestamp < startingTimestamp) return _outstandingRewards;
        uint64 _consolidationTimestamp =
            uint64(Math.min(block.timestamp, endingTimestamp));
        uint256 _lastPeriodDuration =
            uint256(_consolidationTimestamp - lastConsolidationTimestamp);
        if (_lastPeriodDuration == 0) return _outstandingRewards;
        uint256 _unconsolidatedDuration =
            uint256(endingTimestamp - lastConsolidationTimestamp);
        Staker storage _staker = stakers[_account];
        for (uint256 _i; _i < rewards.length; _i++) {
            Reward storage _reward = rewards[_i];
            StakerRewardInfo storage _stakerRewardInfo =
                _staker.rewardInfo[_reward.token];
            _outstandingRewards[_i] = (_stakerRewardInfo.earned -
                _stakerRewardInfo.claimed);
            if (_staker.stake == 0) continue;
            _outstandingRewards[_i] +=
                ((_staker.stake * _lastPeriodDuration * _reward.unassigned) /
                    MULTIPLIER) /
                totalStakedTokensAmount /
                _unconsolidatedDuration;
        }
        return _outstandingRewards;
    }

    function getRewardTokens() external view returns (address[] memory) {
        address[] memory _rewardTokens = new address[](rewards.length);
        for (uint256 _i = 0; _i < rewards.length; _i++) {
            _rewardTokens[_i] = rewards[_i].token;
        }
        return _rewardTokens;
    }

    function rewardAmount(address _rewardToken)
        external
        view
        returns (uint256)
    {
        for (uint256 _i = 0; _i < rewards.length; _i++) {
            Reward storage _reward = rewards[_i];
            if (_rewardToken == _reward.token) return _reward.amount;
        }
        return 0;
    }

    function stakedTokensOf(address _staker) external view returns (uint256) {
        return stakers[_staker].stake;
    }

    function earnedRewardsOf(address _staker)
        external
        view
        returns (uint256[] memory)
    {
        Staker storage _stakerFromStorage = stakers[_staker];
        uint256[] memory _earnedRewards = new uint256[](rewards.length);
        for (uint256 _i; _i < rewards.length; _i++) {
            _earnedRewards[_i] = _stakerFromStorage.rewardInfo[
                rewards[_i].token
            ]
                .earned;
        }
        return _earnedRewards;
    }

    function recoverableUnassignedReward(address _rewardToken)
        external
        view
        returns (uint256)
    {
        require(block.timestamp >= endingTimestamp, "SRD12");
        for (uint256 _i = 0; _i < rewards.length; _i++) {
            Reward storage _reward = rewards[_i];
            if (_reward.token == _rewardToken)
                return _reward.unassigned / MULTIPLIER;
        }
        return 0;
    }

    function getClaimedRewards(address _claimer)
        external
        view
        returns (uint256[] memory)
    {
        Staker storage _staker = stakers[_claimer];
        uint256[] memory _claimedRewards = new uint256[](rewards.length);
        for (uint256 _i = 0; _i < rewards.length; _i++) {
            Reward storage _reward = rewards[_i];
            _claimedRewards[_i] = _staker.rewardInfo[_reward.token].claimed;
        }
        return _claimedRewards;
    }

    function renounceOwnership() public onlyOwner {
        owner = address(0);
        emit OwnershipTransferred(owner, address(0));
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "SRD16");
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "SRD17");
        _;
    }

    modifier onlyUninitialized() {
        require(!initialized, "SRD18");
        _;
    }

    modifier onlyStarted() {
        require(
            initialized && !canceled && block.timestamp >= startingTimestamp,
            "SRD20"
        );
        _;
    }

    modifier onlyRunning() {
        require(
            initialized &&
                !canceled &&
                block.timestamp >= startingTimestamp &&
                block.timestamp <= endingTimestamp,
            "SRD21"
        );
        _;
    }
}
