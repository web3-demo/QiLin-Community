pragma solidity 0.7.6;

interface IExecutorManager {
    function addLegalExecutor(address user) external;
    function removeLegalExecutor(address user) external;
    function IsLegalExecutor(address user) external view returns(bool); 
}