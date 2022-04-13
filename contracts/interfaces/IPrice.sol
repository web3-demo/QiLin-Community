pragma solidity 0.7.6;

interface IPrice {
    function getPrice(address oraclePool_,bool reserve_,int256 precisionDiff_) external view returns (uint256);

    function getPrecisionDiff(address oraclePool_) external view returns (int256 precisionDiff);
}