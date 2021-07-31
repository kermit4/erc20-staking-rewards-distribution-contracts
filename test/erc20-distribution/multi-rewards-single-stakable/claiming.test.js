const fs = require('fs')
require("../../utils/assertion.js");
const BN = require("bn.js");
const { expect } = require("chai");
const { MAXIMUM_VARIANCE, ZERO_BN } = require("../../constants");
const {
    initializeDistribution,
    initializeStaker,
    stakeAtTimestamp,
    withdrawAtTimestamp,
} = require("../../utils");
const { toWei } = require("../../utils/conversion");
const {
    stopMining,
    startMining,
    fastForwardTo,
    getEvmTimestamp,
} = require("../../utils/network");

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
    "ERC20StakingRewardsDistribution - Single stakable, multi reward tokens - Claiming",
    () => {
        let erc20DistributionFactoryInstance,
            rewardTokenInstance=[],
            stakableTokenInstance,
            ownerAddress,
            firstStakerAddress,
            secondStakerAddress,
            thirdStakerAddress;

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
            rewardTokenInstance[0] = await FirstRewardERC20.new();
            rewardTokenInstance[1] = await SecondRewardERC20.new();
            stakableTokenInstance = await FirstStakableERC20.new();
            firstStakerAddress = accounts[1];
            secondStakerAddress = accounts[2];
            thirdStakerAddress = accounts[3];
        });


        fs.readFileSync('test.csv','utf8')
            .split('\n===\n')
            .forEach(
                test =>  {
                    console.log("test"); console.log(test);console.log("\n");
                    var testlines = test.split('\n');
                    console.log("testlines"); console.log(testlines);console.log("\n");
                    var initCols=row[0].split(',');
                    async function generic_one() { // closure preserves the current scope not just the namespace, future mods will modify what it references when it does  "test" didnt seem to change before they were called, i guess its a new test Each?
                        var stakedAmount=0;
                        var splitLines = [];
                        var rewardAmount = [];
                        var lasttime=0;
                        console.log("initCols"); console.log(initCols);console.log("\n");
                        const duration = initCols[2];
                        console.log(console.log("testing " + testlines + "\n"));
                        testlines
                            .forEach(
                                async row => { 

                                    console.log("row"); console.log(row);console.log("\n");
                                    var col=row.split(",");
                                    console.log("col"); console.log(col);console.log("\n");
                                    let thisTime=col[0];
                                    if(thisTime>lasttime) {
                                        await fastForwardTo({ timestamp: startingTimestamp.add(new BN(thisTime)) });
                                        lasttime=thisTime;
                                    }
                                    switch(col[1]) {
                                        case 'reward':
                                            if(thisTime==0) {
                                                const rewardAmount = [];
                                                rewardAmount[col[2]]=await toWei(col[3],rewardTokenInstance[col[2]]);
                                                var {
                                                    erc20DistributionInstance,
                                                    startingTimestamp,
                                                    endingTimestamp,
                                                } = await initializeDistribution({
                                                    from: ownerAddress,
                                                    erc20DistributionFactoryInstance,
                                                    stakableToken: stakableTokenInstance,
                                                    rewardTokens: [
                                                        rewardTokenInstance[0],
                                                        rewardTokenInstance[1],
                                                    ],
                                                    rewardAmounts: [rewardAmount[0], rewardAmount[1]],
                                                    duration: duration,
                                                });
                                                await initializeStaker({
                                                    erc20DistributionInstance,
                                                    stakableTokenInstance,
                                                    stakerAddress: firstStakerAddress,
                                                    stakableAmount: stakedAmount,
                                                });
                                                await fastForwardTo({
                                                    timestamp: startingTimestamp,
                                                });
                                            }

                                        case 'staker': 
                                            if(thisTime==0) {
                                                stakedAmount = await toWei(col[3], stakableTokenInstance);
                                                await stakeAtTimestamp(
                                                    erc20DistributionInstance,
                                                    firstStakerAddress,
                                                    stakedAmount,
                                                    startingTimestamp
                                                );
                                                const stakerStartingTimestamp = await getEvmTimestamp();
                                                expect(stakerStartingTimestamp).to.be.equalBn(startingTimestamp);
                                                // make sure the distribution has ended
                                            } 
                                        case 'claimall': 
                                            try {
                                                await erc20DistributionInstance.claimAll(firstStakerAddress, {
                                                    from: firstStakerAddress,
                                                });
                                                if(col[2]) throw new Error("should have failed");
                                            } catch (error) {
                                                expect(error.message).to.contain(col[2]);
                                            }
                                            const onchainStartingTimestamp = await erc20DistributionInstance.startingTimestamp();
                                            const onchainEndingTimestamp = await erc20DistributionInstance.endingTimestamp();
                                            expect(onchainStartingTimestamp).to.be.equalBn(startingTimestamp);
                                            expect(onchainEndingTimestamp).to.be.equalBn(endingTimestamp);
                                            const stakingDuration = onchainEndingTimestamp.sub(
                                                onchainStartingTimestamp
                                            );

                                            expect(stakingDuration).to.be.equalBn(new BN(duration));
                                            const firstStakerRewardsTokenBalance = await rewardTokenInstance[0].balanceOf(
                                                firstStakerAddress
                                            );
                                            expect(firstStakerRewardsTokenBalance).to.equalBn(
                                                rewardAmount[0]
                                            );
                                            // additional checks to be extra safe
                                            expect(firstStakerRewardsTokenBalance).to.equalBn(
                                                rewardAmount[0]
                                            );

                                            const secondStakerRewardsTokenBalance = await rewardTokenInstance[1].balanceOf(
                                                firstStakerAddress
                                            );
                                            expect(secondStakerRewardsTokenBalance).to.equalBn(
                                                rewardAmount[1]
                                            );
                                            // additional checks to be extra safe
                                            expect(secondStakerRewardsTokenBalance).to.equalBn(
                                                rewardAmount[1]
                                            );
                                    };

                                })} 
                    it(initCols[0] , generic_one);
                });



    }
);
