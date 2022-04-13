pragma solidity 0.7.6;
pragma abicoder v2;


interface IRouter {
    event RelationCreate(address sender, address upAddress);

    enum AgentParam {
        OwnerRate,
        ContributeRate,
        SecondUpperRate,
        ExecPreBillAmount,
        ExecPositionAmount
    }


    struct strategy {
        uint32 strategyType;
        uint256 value;
    }


    event StrategySheet(uint32 tokenId,uint32 strategyType,uint256 value);

    event TokenCreate(uint32 tokenId, address pool, address sender, uint32 positionId,
        address excutorAddress);

    event SetAgentParam(AgentParam paramType,uint256 paramValue);

    event AddContribute(address user,address token,uint256 amount);

    event ClaimContribute(address user,address token);

    event OpenPreBill(
        address owner,
        uint32 tokenId,
        address poolAddress,       
        uint8 direction,
        uint16 leverage,
        uint256 position,
        address excutorAddress
    );

    event CancleBill(uint32 tokenId);

    event SetExecutor(uint32 tokenId,address executor);

    event ExecPreBill(uint32 tokenId,address executor);

    function openPreBill(
        address oracleAddress,
        address poolToken,
        uint8 direction,
        uint16 leverage,
        uint256 position,
        address excutorAddress,
        strategy[] memory strategyDatas) external payable;

    
    function setExecutor(
        uint32 tokenId,
        uint8 billType,
        address executor
    ) external  payable;

    function execPreBill(uint32 tokenId) external ;

    function createPool(
        address oracleAddress,
        address poolToken
    ) external;

    function getLsBalance(
        address oracleAddress,
        address poolToken,
        address user
    ) external view returns (uint256);

    function getLsPrice(
        address oracleAddress,
        address poolToken
    ) external view returns (uint256);

    function addLiquidity(
        address oracleAddress,
        address poolToken,
        uint256 amount
    ) external payable;

    function removeLiquidity(
        address oracleAddress,
        address poolToken,
        uint256 lsAmount,
        uint256 bondsAmount,
        address receipt
    ) external;

    function openPosition(
        address oracleAddress,
        address poolToken,
        uint8 direction,
        uint16 leverage,
        uint256 position,
        address excutorAddress,
        strategy[] memory strategyDatas
    ) external payable;

    function addMargin(uint32 tokenId, uint256 margin) external payable;

    function closeAgentPosition(uint32 tokenId) external;

    function liquidate(uint32 tokenId, address receipt) external;

    function liquidateByPool(address poolAddress, uint32 positionId, address receipt) external;

    function exit(uint32 tokenId, address receipt) external;

    function repayLoan(
        address oracleAddress,
        address poolToken,
        uint256 amount,
        address receipt
    ) external payable;
}
