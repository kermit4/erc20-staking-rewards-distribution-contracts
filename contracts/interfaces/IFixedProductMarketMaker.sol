pragma solidity >=0.8.0;

interface IFixedProductMarketMaker {
    function collateralToken() external view returns (address);

    function feesWithdrawableBy(address account)
        external
        view
        returns (uint256);
}
