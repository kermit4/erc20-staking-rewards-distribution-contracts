// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./interfaces/IERC20StakingRewardsDistribution.sol";

/**
 * Error codes:
 *
 * SRDF01: invalid distribution address
 */
contract ERC20StakingRewardsDistributionFactory is Ownable {
    using SafeERC20 for IERC20;

    address public implementation;
    IERC20StakingRewardsDistribution[] public distributions;
    mapping(address => bool) validDistributions;

    event DistributionCreated(address owner, address deployedAt);

    constructor(address _implementation) {
        implementation = _implementation;
    }

    function upgradeImplementation(address _implementation) external onlyOwner {
        implementation = _implementation;
    }

    function createDistribution(
        address[] calldata _rewardTokenAddresses,
        address _stakableTokenAddress,
        uint256[] calldata _rewardAmounts,
        uint64 _startingTimestamp,
        uint64 _endingTimestamp,
        bool _locked,
        uint256 _stakingCap
    ) public virtual {
        address _distributionProxy = Clones.clone(implementation);
        for (uint256 _i; _i < _rewardTokenAddresses.length; _i++) {
            uint256 _relatedAmount = _rewardAmounts[_i];
            if (_relatedAmount > 0) {
                IERC20(_rewardTokenAddresses[_i]).safeTransferFrom(
                    msg.sender,
                    address(_distributionProxy),
                    _relatedAmount
                );
            }
        }
        IERC20StakingRewardsDistribution _distribution =
            IERC20StakingRewardsDistribution(_distributionProxy);
        _distribution.initialize(
            _rewardTokenAddresses,
            _stakableTokenAddress,
            _rewardAmounts,
            _startingTimestamp,
            _endingTimestamp,
            _locked,
            _stakingCap
        );
        address _owner = owner();
        _distribution.transferOwnership(_owner);
        distributions.push(_distribution);
        validDistributions[address(_distribution)] = true;
        emit DistributionCreated(_owner, address(_distribution));
    }

    function approveDistribution(
        address _distribution,
        uint256 _amount,
        address _token
    ) external onlyOwner {
        require(validDistributions[_distribution] == true, "SRDF01");
        IERC20 _rewardToken = IERC20(_token);
        _rewardToken.approve(_distribution, _amount);
    }

    function fundDistribution(
        address _distribution,
        uint256 _amount,
        address _token
    ) external onlyOwner {
        require(validDistributions[_distribution] == true, "SRDF01");
        IERC20StakingRewardsDistribution _distributionContract =
            IERC20StakingRewardsDistribution(_distribution);
        _distributionContract.addRewards(_token, _amount);
    }

    function getDistributionsAmount() external view returns (uint256) {
        return distributions.length;
    }
}
