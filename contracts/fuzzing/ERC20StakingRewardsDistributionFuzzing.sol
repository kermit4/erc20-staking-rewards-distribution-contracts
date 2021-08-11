pragma solidity ^0.8.4;

import {
    ERC20StakingRewardsDistribution,
    ERC20StakingRewardsDistributionFactory,
    TestERC20,
    IERC20
} from "./FlattenedERC20StakingRewardsDistribution.sol";

contract MockUser {
    ERC20StakingRewardsDistribution internal distribution;
    address stakingToken;

    constructor(address _distribution, address _stakingToken) {
        distribution = ERC20StakingRewardsDistribution(_distribution);
        stakingToken = _stakingToken;
        // Approve staking tokens to distribution
        IERC20(_stakingToken).approve(_distribution, type(uint256).max);
    }

    // Test stake function
    function stake(uint256 amount) public {
        distribution.stake(amount);
    }

    // Test withdraw function
    function withdraw(uint256 amount) public {
        distribution.withdraw(amount);
    }

    // Test claim function
    function claim(uint256[] memory amounts) public {
        distribution.claim(amounts, address(this));
    }

    // Test claimAll function
    function claimAll() public {
        distribution.claimAll(address(this));
    }

    // Test cancel function
    function cancel() public {
        distribution.cancel();
    }

    // Test addRewards function
    function addRewards(address rewardToken, uint256 amount) public {
        distribution.addRewards(rewardToken, amount);
    }

    // Test recoverUnassignedRewards function
    function recoverUnassignedRewards() public {
        distribution.recoverUnassignedRewards();
    }
}

contract ERC20StakingRewardsDistributionFuzzing {
    ERC20StakingRewardsDistribution internal distribution;
    address[] rewardTokens;
    uint256[] rewardAmounts;
    MockUser mockUser;

    IERC20 token1;
    IERC20 token2;
    IERC20 token3;

    event AssertionFailed();

    constructor() {
        // Create two reward tokens and one staking token
        token1 = new TestERC20("token1", "tkn1");
        token2 = new TestERC20("token2", "tkn2");
        token3 = new TestERC20("token3", "tkn3");

        // Populate reward token and amounts arrays
        rewardTokens.push(address(token1));
        rewardTokens.push(address(token2));
        rewardAmounts.push(uint256(1 * 10**18));
        rewardAmounts.push(uint256(2 * 10**18));

        // Instantiate reference distribution implementation
        ERC20StakingRewardsDistribution implementation =
            new ERC20StakingRewardsDistribution();

        // Instantiate factory with reference implementation
        ERC20StakingRewardsDistributionFactory factory =
            new ERC20StakingRewardsDistributionFactory(address(implementation));

        // Approve reward tokens to factory
        token1.approve(address(factory), 1 * 10**18);
        token2.approve(address(factory), 2 * 10**18);

        // Create distribution
        factory.createDistribution(
            rewardTokens,
            address(token3),
            rewardAmounts,
            uint64(block.timestamp),
            uint64(block.timestamp + 10000),
            false,
            1000000000
        );

        // Store distribution
        distribution = ERC20StakingRewardsDistribution(
            address(factory.distributions(0))
        );

        // Approve staking token to distribution
        token3.approve(address(distribution), 10000 * 10**18);

        // Create mock user
        mockUser = new MockUser(address(distribution), address(token3));
        // Transfer some staking tokens to mock user
        token3.transfer(address(mockUser), 100 * 10**18);
    }

    // Test stake function
    function stake(uint256 amount) public {
        uint256 stakerTokenBalanceBefore = token3.balanceOf(address(this));
        uint256 totalStakedBefore = distribution.totalStakedTokensAmount();
        uint256 stakedTokensBefore = distribution.stakedTokensOf(address(this));
        distribution.stake(amount);
        uint256 stakerTokenBalanceAfter = token3.balanceOf(address(this));
        uint256 totalStakedAfter = distribution.totalStakedTokensAmount();
        uint256 stakedTokensAfter = distribution.stakedTokensOf(address(this));

        // Assert that staker token balance decreases by amount
        if (stakerTokenBalanceBefore - amount != stakerTokenBalanceAfter) {
            emit AssertionFailed();
        }
        // Assert that total staked increases by amount
        if (totalStakedBefore + amount != totalStakedAfter) {
            emit AssertionFailed();
        }
        // Assert that staked tokens increases by amount
        if (stakedTokensBefore + amount != stakedTokensAfter) {
            emit AssertionFailed();
        }
    }

    // Test stake function as user
    function stakeAsUser(uint256 amount) public {
        uint256 stakerTokenBalanceBefore = token3.balanceOf(address(mockUser));
        uint256 totalStakedBefore = distribution.totalStakedTokensAmount();
        uint256 stakedTokensBefore =
            distribution.stakedTokensOf(address(mockUser));
        mockUser.stake(amount);
        uint256 stakerTokenBalanceAfter = token3.balanceOf(address(mockUser));
        uint256 totalStakedAfter = distribution.totalStakedTokensAmount();
        uint256 stakedTokensAfter =
            distribution.stakedTokensOf(address(mockUser));

        // Assert that staker token balance decreases by amount
        if (stakerTokenBalanceBefore - amount != stakerTokenBalanceAfter) {
            emit AssertionFailed();
        }
        // Assert that total staked increases by amount
        if (totalStakedBefore + amount != totalStakedAfter) {
            emit AssertionFailed();
        }
        // Assert that staked tokens increases by amount
        if (stakedTokensBefore + amount != stakedTokensAfter) {
            emit AssertionFailed();
        }
    }

    // Test withdraw function
    function withdraw(uint256 amount) public {
        uint256 stakerTokenBalanceBefore = token3.balanceOf(address(this));
        uint256 totalStakedBefore = distribution.totalStakedTokensAmount();
        uint256 stakedTokensBefore = distribution.stakedTokensOf(address(this));
        distribution.withdraw(amount);
        uint256 stakerTokenBalanceAfter = token3.balanceOf(address(this));
        uint256 totalStakedAfter = distribution.totalStakedTokensAmount();
        uint256 stakedTokensAfter = distribution.stakedTokensOf(address(this));

        // Assert that staker token balance increases by amount
        if (stakerTokenBalanceBefore + amount != stakerTokenBalanceAfter) {
            emit AssertionFailed();
        }
        // Assert that total staked decreases by amount
        if (totalStakedBefore - amount != totalStakedAfter) {
            emit AssertionFailed();
        }
        // Assert that staked tokens decreases by amount
        if (stakedTokensBefore - amount != stakedTokensAfter) {
            emit AssertionFailed();
        }
    }

    // Test withdraw function as user
    function withdrawAsUser(uint256 amount) public {
        uint256 stakerTokenBalanceBefore = token3.balanceOf(address(mockUser));
        uint256 totalStakedBefore = distribution.totalStakedTokensAmount();
        uint256 stakedTokensBefore =
            distribution.stakedTokensOf(address(mockUser));
        mockUser.withdraw(amount);
        uint256 stakerTokenBalanceAfter = token3.balanceOf(address(mockUser));
        uint256 totalStakedAfter = distribution.totalStakedTokensAmount();
        uint256 stakedTokensAfter =
            distribution.stakedTokensOf(address(mockUser));

        // Assert that staker token balance increases by amount
        if (stakerTokenBalanceBefore + amount != stakerTokenBalanceAfter) {
            emit AssertionFailed();
        }
        // Assert that total staked decreases by amount
        if (totalStakedBefore - amount != totalStakedAfter) {
            emit AssertionFailed();
        }
        // Assert that staked tokens decreases by amount
        if (stakedTokensBefore - amount != stakedTokensAfter) {
            emit AssertionFailed();
        }
    }

    // Test claim function
    function claim(uint256[] memory amounts) public {
        uint256 rewardBalancesBefore1 = token1.balanceOf(address(this));
        uint256 rewardBalancesBefore2 = token2.balanceOf(address(this));
        distribution.claim(amounts, address(this));
        uint256 rewardBalancesAfter1 = token1.balanceOf(address(this));
        uint256 rewardBalancesAfter2 = token2.balanceOf(address(this));

        // Assert that reward token balances are increasing at least by expected amounts
        if (rewardBalancesBefore1 + amounts[0] > rewardBalancesAfter1) {
            emit AssertionFailed();
        }
        if (rewardBalancesBefore2 + amounts[1] > rewardBalancesAfter2) {
            emit AssertionFailed();
        }
    }

    // Test claim function as user
    function claimAsUser(uint256[] memory amounts) public {
        uint256 rewardBalancesBefore1 = token1.balanceOf(address(mockUser));
        uint256 rewardBalancesBefore2 = token2.balanceOf(address(mockUser));
        mockUser.claim(amounts);
        uint256 rewardBalancesAfter1 = token1.balanceOf(address(mockUser));
        uint256 rewardBalancesAfter2 = token2.balanceOf(address(mockUser));

        // Assert that reward token balances are increasing at least by expected amounts
        if (rewardBalancesBefore1 + amounts[0] > rewardBalancesAfter1) {
            emit AssertionFailed();
        }
        if (rewardBalancesBefore2 + amounts[1] > rewardBalancesAfter2) {
            emit AssertionFailed();
        }
    }

    // Test claimAll function
    function claimAll() public {
        uint256[] memory claimableRewards =
            distribution.claimableRewards(address(this));

        uint256 rewardBalancesBefore1 = token1.balanceOf(address(this));
        uint256 rewardBalancesBefore2 = token2.balanceOf(address(this));
        distribution.claimAll(address(this));
        uint256 rewardBalancesAfter1 = token1.balanceOf(address(this));
        uint256 rewardBalancesAfter2 = token2.balanceOf(address(this));

        // Assert that reward token balances are increasing at least by expected amounts - 1 wei rounding buffer
        if (
            (rewardBalancesBefore1 + claimableRewards[0]) >
            (rewardBalancesAfter1 + 1)
        ) {
            emit AssertionFailed();
        }
        if (
            (rewardBalancesBefore2 + claimableRewards[1]) >
            (rewardBalancesAfter2 + 1)
        ) {
            emit AssertionFailed();
        }
    }

    // Test claimAll function as user
    function claimAllAsUser() public {
        uint256[] memory claimableRewards =
            distribution.claimableRewards(address(mockUser));

        uint256 rewardBalancesBefore1 = token1.balanceOf(address(mockUser));
        uint256 rewardBalancesBefore2 = token2.balanceOf(address(mockUser));
        mockUser.claimAll();
        uint256 rewardBalancesAfter1 = token1.balanceOf(address(mockUser));
        uint256 rewardBalancesAfter2 = token2.balanceOf(address(mockUser));

        // Assert that reward token balances are increasing at least by expected amounts - 1 wei rounding buffer
        if (
            (rewardBalancesBefore1 + claimableRewards[0]) >
            (rewardBalancesAfter1 + 1)
        ) {
            emit AssertionFailed();
        }
        if (
            (rewardBalancesBefore2 + claimableRewards[1]) >
            (rewardBalancesAfter2 + 1)
        ) {
            emit AssertionFailed();
        }
    }

    // Test cancel function
    function cancel() public {
        distribution.cancel();

        // Assert revert since after startingTimestamp
        emit AssertionFailed();
    }

    // Test cancel function as user
    function cancelAsUser() public {
        mockUser.cancel();

        // Assert revert since after startingTimestamp
        emit AssertionFailed();
    }

    // Test addRewards function
    function addRewards(uint256 seed, uint256 amount) public {
        address rewardToken;
        if (seed % 2 == 0) {
            rewardToken = address(token1);
        } else {
            rewardToken = address(token2);
        }
        uint256 distributionRewardAmountBefore =
            distribution.rewardAmount(rewardToken);
        uint256 distributionRewardBalanceBefore =
            IERC20(rewardToken).balanceOf(address(distribution));
        distribution.addRewards(rewardToken, amount);
        uint256 distributionRewardAmountAfter =
            distribution.rewardAmount(rewardToken);
        uint256 distributionRewardBalanceAfter =
            IERC20(rewardToken).balanceOf(address(distribution));

        // Assert that tracked reward amount is correctly increased
        if (
            distributionRewardAmountBefore + amount !=
            distributionRewardAmountAfter
        ) {
            emit AssertionFailed();
        }
        // Assert that distribution reward balance is properly increased
        if (
            distributionRewardBalanceBefore + amount !=
            distributionRewardBalanceAfter
        ) {
            emit AssertionFailed();
        }
    }

    // Test addRewards function as user
    function addRewardsAsUser(uint256 seed, uint256 amount) public {
        address rewardToken;
        if (seed % 2 == 0) {
            rewardToken = address(token1);
        } else {
            rewardToken = address(token2);
        }
        uint256 distributionRewardAmountBefore =
            distribution.rewardAmount(rewardToken);
        uint256 distributionRewardBalanceBefore =
            IERC20(rewardToken).balanceOf(address(distribution));
        mockUser.addRewards(rewardToken, amount);
        uint256 distributionRewardAmountAfter =
            distribution.rewardAmount(rewardToken);
        uint256 distributionRewardBalanceAfter =
            IERC20(rewardToken).balanceOf(address(distribution));

        // Assert that tracked reward amount is correctly increased
        if (
            distributionRewardAmountBefore + amount !=
            distributionRewardAmountAfter
        ) {
            emit AssertionFailed();
        }
        // Assert that distribution reward balance is properly increased
        if (
            distributionRewardBalanceBefore + amount !=
            distributionRewardBalanceAfter
        ) {
            emit AssertionFailed();
        }
    }

    // Test recoverUnassignedRewards function
    function recoverUnassignedRewards() public {
        uint256 recoverableRewards1 =
            distribution.recoverableUnassignedReward(address(token1));
        uint256 recoverableRewards2 =
            distribution.recoverableUnassignedReward(address(token2));
        uint256 ownerRewardBalancesBefore1 = token1.balanceOf(address(this));
        uint256 ownerRewardBalancesBefore2 = token2.balanceOf(address(this));

        distribution.recoverUnassignedRewards();

        uint256 ownerRewardBalancesAfter1 = token1.balanceOf(address(this));
        uint256 ownerRewardBalancesAfter2 = token2.balanceOf(address(this));

        // Assert owner balances increase by at least expected amount
        if (
            (ownerRewardBalancesBefore1 + recoverableRewards1) >
            ownerRewardBalancesAfter1
        ) {
            emit AssertionFailed();
        }
        if (
            (ownerRewardBalancesBefore2 + recoverableRewards2) >
            ownerRewardBalancesAfter2
        ) {
            emit AssertionFailed();
        }
    }

    // Test recoverUnassignedRewardsAsUser function
    function recoverUnassignedRewardsAsUser() public {
        uint256 recoverableRewards1 =
            distribution.recoverableUnassignedReward(address(token1));
        uint256 recoverableRewards2 =
            distribution.recoverableUnassignedReward(address(token2));
        uint256 ownerRewardBalancesBefore1 = token1.balanceOf(address(this));
        uint256 ownerRewardBalancesBefore2 = token2.balanceOf(address(this));

        mockUser.recoverUnassignedRewards();

        uint256 ownerRewardBalancesAfter1 = token1.balanceOf(address(this));
        uint256 ownerRewardBalancesAfter2 = token2.balanceOf(address(this));

        // Assert owner balances increase by at least expected amount
        if (
            (ownerRewardBalancesBefore1 + recoverableRewards1) >
            ownerRewardBalancesAfter1
        ) {
            emit AssertionFailed();
        }
        if (
            (ownerRewardBalancesBefore2 + recoverableRewards2) >
            ownerRewardBalancesAfter2
        ) {
            emit AssertionFailed();
        }
    }
}
