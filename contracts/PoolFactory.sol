pragma solidity 0.7.6;

import "./libraries/StrConcat.sol";
import "./interfaces/IPoolFactory.sol";
import "./interfaces/IDeployer01.sol";
import "./SystemSettings.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract PoolFactory is IPoolFactory, SystemSettings {
    mapping(address => mapping(address =>address)) public override pools;

    address private _deployer01;

    constructor(
        address deployer01,
        address deployer02) SystemSettings(deployer02) {
        _deployer01 = deployer01;
    }

    function createPool(address oracleAddress_, address poolToken) external override {

        require(oracleAddress_ != address(0), "trade pair not found in uni swap");
        require(pools[poolToken][oracleAddress_] == address(0), "pool already exists");

        string memory tradePair = StrConcat.strConcat("Pool",ERC20(poolToken).symbol());
        (address pool, address debt) = IDeployer01(_deployer01).deploy(poolToken, oracleAddress_, address(this), tradePair);
        pools[poolToken][oracleAddress_] = pool;

        emit CreatePool(poolToken, oracleAddress_, pool, debt, tradePair);
    }


}
