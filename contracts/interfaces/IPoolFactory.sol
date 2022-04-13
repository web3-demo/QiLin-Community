pragma solidity 0.7.6;

interface IPoolFactory {
    function createPool(address oracleAddress_, address poolToken) external;

    function pools(address poolToken, address uniPool) external view returns (address pool);

    event CreatePool(
        address poolToken,
        address uniPool,
        address pool,
        address debt,
        string tradePair
    );
}
