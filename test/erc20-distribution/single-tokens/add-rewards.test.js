require("../../utils/assertion.js"); 
const BN = require("bn.js");
const {
    expectEvent,
    expectRevert,
} = require("@openzeppelin/test-helpers");
const { expect } = require("chai");
const { initializeDistribution } = require("../../utils");

const ERC20StakingRewardsDistribution = artifacts.require(
    "ERC20StakingRewardsDistribution"
);
const ERC20StakingRewardsDistributionFactory = artifacts.require(
    "ERC20StakingRewardsDistributionFactory"
);
const FirstRewardERC20 = artifacts.require("FirstRewardERC20");
const SecondRewardERC20 = artifacts.require("SecondRewardERC20");
const FirstStakableERC20 = artifacts.require("FirstStakableERC20");

contract(
    "ERC20StakingRewardsDistribution - Single reward/stakable token - Get claimable rewards",
    () => {
        let erc20DistributionFactoryInstance,
            firstRewardTokenInstance,
            secondRewardTokenInstance,
            stakableTokenInstance,
            ownerAddress,
            firstStakerAddress;

        beforeEach(async () => {
            const accounts = await web3.eth.getAccounts();
            ownerAddress = accounts[0];
            const erc20DistributionInstance = await ERC20StakingRewardsDistribution.new(
                { from: ownerAddress }
            );
            erc20DistributionFactoryInstance = await ERC20StakingRewardsDistributionFactory.new(
                erc20DistributionInstance.address,
                { from: ownerAddress }
            );
            firstStakerAddress = accounts[1];
            firstRewardTokenInstance = await FirstRewardERC20.new();
            secondRewardTokenInstance = await SecondRewardERC20.new();
            stakableTokenInstance = await FirstStakableERC20.new();
            firstStakerAddress = accounts[1];
        });

        it("addRewards", async () => {
            const { erc20DistributionInstance } = await initializeDistribution({
                from: ownerAddress,
                erc20DistributionFactoryInstance,
                stakableToken: stakableTokenInstance,
                rewardTokens: [
                    firstRewardTokenInstance,
                    secondRewardTokenInstance,
                ],
                rewardAmounts: ["10", "1"],
                duration: 10,
            });
            const addRewards = await erc20DistributionInstance.addRewards(
                firstStakerAddress, 
                1
            );
            console.log(addRewards);
            expectEvent(addRewards, "UpdatedRewards", {
            });
            const rewards  = erc20DistributionInstance.rewards;
            console.log(rewards);
            const reward = rewards[rewards.length-1];
            console.log(reward);
            assert.equal(reward.amount,1);
            assert.equal(reward.token,firstStakerAddress);
        });
    }
);
