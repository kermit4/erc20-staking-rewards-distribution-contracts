const BN = require("bn.js");
const { expect } = require("chai");
const {
    initializeDistribution,
    initializeStaker,
    withdraw,
    stakeAtTimestamp,
    withdrawAtTimestamp,
} = require("../../utils");
const { toWei } = require("../../utils/conversion");
const { fastForwardTo } = require("../../utils/network");

const ERC20Staker = artifacts.require("ERC20Staker");
const FirstRewardERC20 = artifacts.require("FirstRewardERC20");
const FirstStakableERC20 = artifacts.require("FirstStakableERC20");

contract("ERC20Staker - Single reward/stakable token - Withdrawing", () => {
    let erc20StakerInstance,
        rewardsTokenInstance,
        stakableTokenInstance,
        ownerAddress,
        stakerAddress;

    beforeEach(async () => {
        const accounts = await web3.eth.getAccounts();
        ownerAddress = accounts[0];
        erc20StakerInstance = await ERC20Staker.new({ from: ownerAddress });
        rewardsTokenInstance = await FirstRewardERC20.new();
        stakableTokenInstance = await FirstStakableERC20.new();
        stakerAddress = accounts[1];
    });

    it("should fail when initialization has not been done", async () => {
        try {
            await erc20StakerInstance.withdraw([0]);
            throw new Error("should have failed");
        } catch (error) {
            expect(error.message).to.contain("ERC20Staker: not initialized");
        }
    });

    it("should fail when the distribution has not yet started", async () => {
        try {
            await initializeDistribution({
                from: ownerAddress,
                erc20Staker: erc20StakerInstance,
                stakableTokens: [stakableTokenInstance],
                rewardTokens: [rewardsTokenInstance],
                rewardAmounts: [1],
                duration: 2,
            });
            await erc20StakerInstance.withdraw([0]);
            throw new Error("should have failed");
        } catch (error) {
            expect(error.message).to.contain("ERC20Staker: not started");
        }
    });

    it("should fail when the staker tries to withdraw more than what they staked", async () => {
        try {
            await initializeStaker({
                erc20StakerInstance,
                stakableTokenInstance,
                stakerAddress: stakerAddress,
                stakableAmount: 1,
            });
            const { startingTimestamp } = await initializeDistribution({
                from: ownerAddress,
                erc20Staker: erc20StakerInstance,
                stakableTokens: [stakableTokenInstance],
                rewardTokens: [rewardsTokenInstance],
                rewardAmounts: [1],
                duration: 10,
            });
            await fastForwardTo({ timestamp: startingTimestamp });
            await stakeAtTimestamp(
                erc20StakerInstance,
                stakerAddress,
                [1],
                startingTimestamp
            );
            await erc20StakerInstance.withdraw([2]);
            throw new Error("should have failed");
        } catch (error) {
            expect(error.message).to.contain(
                "ERC20Staker: withdrawn amount greater than current stake"
            );
        }
    });

    it("should succeed in the right conditions, when the distribution has not yet ended", async () => {
        const stakedAmount = await toWei(10, stakableTokenInstance);
        await initializeStaker({
            erc20StakerInstance,
            stakableTokenInstance,
            stakerAddress: stakerAddress,
            stakableAmount: stakedAmount,
        });
        const { startingTimestamp } = await initializeDistribution({
            from: ownerAddress,
            erc20Staker: erc20StakerInstance,
            stakableTokens: [stakableTokenInstance],
            rewardTokens: [rewardsTokenInstance],
            rewardAmounts: [await toWei(1, rewardsTokenInstance)],
            duration: 10,
        });
        await fastForwardTo({ timestamp: startingTimestamp });
        await stakeAtTimestamp(
            erc20StakerInstance,
            stakerAddress,
            [stakedAmount],
            startingTimestamp
        );
        expect(
            await erc20StakerInstance.stakedTokensOf(
                stakerAddress,
                stakableTokenInstance.address
            )
        ).to.be.equalBn(stakedAmount);
        await withdraw(erc20StakerInstance, stakerAddress, [
            stakedAmount.div(new BN(2)),
        ]);
        expect(
            await erc20StakerInstance.stakedTokensOf(
                stakerAddress,
                stakableTokenInstance.address
            )
        ).to.be.equalBn(stakedAmount.div(new BN(2)));
        expect(
            await erc20StakerInstance.stakedTokenAmount(
                stakableTokenInstance.address
            )
        ).to.be.equalBn(stakedAmount.div(new BN(2)));
        expect(
            await stakableTokenInstance.balanceOf(stakerAddress)
        ).to.be.equalBn(stakedAmount.div(new BN(2)));
    });

    it("should succeed in the right conditions, when the distribution has already ended", async () => {
        const stakedAmount = await toWei(10, stakableTokenInstance);
        await initializeStaker({
            erc20StakerInstance,
            stakableTokenInstance,
            stakerAddress: stakerAddress,
            stakableAmount: stakedAmount,
        });
        const {
            startingTimestamp,
            endingTimestamp,
        } = await initializeDistribution({
            from: ownerAddress,
            erc20Staker: erc20StakerInstance,
            stakableTokens: [stakableTokenInstance],
            rewardTokens: [rewardsTokenInstance],
            rewardAmounts: [await toWei(1, rewardsTokenInstance)],
            duration: 10,
        });
        await fastForwardTo({ timestamp: startingTimestamp });
        await stakeAtTimestamp(
            erc20StakerInstance,
            stakerAddress,
            [stakedAmount],
            startingTimestamp
        );
        expect(
            await erc20StakerInstance.stakedTokensOf(
                stakerAddress,
                stakableTokenInstance.address
            )
        ).to.be.equalBn(stakedAmount);
        await fastForwardTo({ timestamp: endingTimestamp });
        await withdrawAtTimestamp(
            erc20StakerInstance,
            stakerAddress,
            [stakedAmount.div(new BN(2))],
            endingTimestamp
        );
        expect(
            await erc20StakerInstance.stakedTokensOf(
                stakerAddress,
                stakableTokenInstance.address
            )
        ).to.be.equalBn(stakedAmount.div(new BN(2)));
        expect(
            await erc20StakerInstance.stakedTokenAmount(
                stakableTokenInstance.address
            )
        ).to.be.equalBn(stakedAmount.div(new BN(2)));
        expect(
            await stakableTokenInstance.balanceOf(stakerAddress)
        ).to.be.equalBn(stakedAmount.div(new BN(2)));
    });
});
