pragma solidity 0.7.6;

interface IPoolCallback {
    function poolV2Callback(
        uint256 amount,
        address poolToken,
        address oraclePool,
        address payer
    ) external payable;

    function poolV2RemoveCallback(
        uint256 amount,
        address poolToken,
        address oraclePool,
        address payer
    ) external;

    function poolV2BondsCallback(
        uint256 amount,
        address poolToken,
        address oraclePool,
        address payer
    ) external;

    function poolV2BondsCallbackFromDebt(
        uint256 amount,
        address poolToken,
        address oraclePool,
        address payer
    ) external;
}