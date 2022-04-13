pragma solidity 0.7.6;
pragma abicoder v2;

import "@uniswap/v3-periphery/contracts/base/Multicall.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IExecutorManager.sol";

contract ExecutorManager is Multicall, Ownable ,IExecutorManager{
    event AddLegalExecutor(
        address indexed user
    );

    event RemoveLegalExecutor(
        address indexed user
    );

    constructor() {
    }

    mapping(address => bool) public _legalExecutor;

    function addLegalExecutor(address user) external override onlyOwner {
        _legalExecutor[user] = true;
        emit AddLegalExecutor(user);
    }

    function removeLegalExecutor(address user) external override onlyOwner {
        _legalExecutor[user] = false;
        emit RemoveLegalExecutor(user);
    }

    function IsLegalExecutor(address user) external override view returns(bool) {
        return _legalExecutor[user];
    }
}