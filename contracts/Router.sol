pragma solidity 0.7.6;
pragma abicoder v2;

import "./interfaces/IPoolFactory.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IPoolCallback.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-periphery/contracts/base/Multicall.sol";

import "./interfaces/IRouter.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IDebt.sol";
import "./interfaces/IExecutorManager.sol";

contract Router is IRouter, IPoolCallback, Multicall, Ownable {
    fallback() external {}
    receive() payable external {}
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public _factory;
    address public _wETH;
    uint32 private _tokenId = 0;
    address public _legalExecutor;

    mapping(address => address) public _upRelation;
    mapping(uint32 => preBill) public _preBillData;
    mapping(address => mapping(address => uint256)) public _contribute;
    uint32 public _ownerRate;
    uint32 public _contributeRate;
    uint32 public _secondUpperRate;
    uint256 private constant E4 = 1e4;
    uint256 public _execPreBillAmount;
    uint256 public _execPositionAmount;
    bool private _routerPay;

    modifier routerPay() {
        _routerPay = true;
        _;
        _routerPay = false;
    }

    struct preBill {
        address owner;
        address executor;
        address poolAddress;
        uint8 direction;
        uint16 leverage;
        uint256 position;        
    }

    struct tokenDate {
        address owner;
        address poolAddress;
        address executor;
        uint32 positionId;
    }

    mapping(uint32 => tokenDate) public _tokenData;

    constructor(address factory,  address wETH,address legalExecutor) {
        _legalExecutor = legalExecutor;
        _factory = factory;
        _wETH = wETH;
        _ownerRate = 5;
        _contributeRate = 4;
        _secondUpperRate = 2500;
        _execPreBillAmount = 30000000000000000;
        _execPositionAmount = 10000000000000000;
        _routerPay = false;
    }

    function setOwnerRate(uint32 rate) public onlyOwner {
        require(rate < E4, "invalid contribute rate");
        _ownerRate = rate;
        emit SetAgentParam(AgentParam.OwnerRate,rate);
    }

    function setContributeRate(uint32 rate) public onlyOwner {
        require(rate < _ownerRate , "invalid contribute rate");
        _contributeRate = rate;
        emit SetAgentParam(AgentParam.ContributeRate,rate);
    }

    function setSecondUpperRate(uint32 rate) public onlyOwner {
        require(rate < E4, "invalid second upper rate");
        _secondUpperRate = rate;
        emit SetAgentParam(AgentParam.SecondUpperRate,rate);
    }

    function setExecPreBillAmount(uint256 execPreBillAmount) public onlyOwner {
        _execPreBillAmount = execPreBillAmount;
        emit SetAgentParam(AgentParam.ExecPreBillAmount,execPreBillAmount);
    }

    function setExecPositionAmount(uint256 execPositionAmount) public onlyOwner {
        _execPositionAmount = execPositionAmount;
        emit SetAgentParam(AgentParam.ExecPositionAmount,execPositionAmount);
    }

    function setUpRelation(address upAddress) public {
        require(upAddress != msg.sender, "can't set myself");
        require(upAddress != address(0), "can't address 0");

        _upRelation[msg.sender] = upAddress;
        emit RelationCreate(msg.sender,upAddress);
    }

    function getUserContribute(address user, address tokenAddress)
        public
        view
        returns (uint256)
    {
        return _contribute[user][tokenAddress];
    }

    function claimContribute(address tokenAddress) public {
        IERC20(tokenAddress).safeTransfer(
            msg.sender,
            _contribute[msg.sender][tokenAddress]
        );
        _contribute[msg.sender][tokenAddress] = 0;
        emit ClaimContribute(msg.sender,tokenAddress);
    }

    function poolV2BondsCallback(
        uint256 amount,
        address poolToken,
        address oraclePool,
        address payer
    ) external override {
        address pool = getPool(oraclePool,poolToken);
        require(
             pool == msg.sender,
            "poolV2BondsCallback caller is not the pool contract"
        );

        address debt = IPool(pool).debtToken();

        IERC20(debt).safeTransferFrom(payer, debt, amount);
    }

    function poolV2BondsCallbackFromDebt(
        uint256 amount,
        address poolToken,
        address oraclePool,
        address payer
    ) external override {
        address pool = getPool(oraclePool,poolToken);
        address debt = IPool(pool).debtToken();
        require(
            debt == msg.sender,
            "poolV2BondsCallbackFromDebt caller is not the debt contract"
        );

        IERC20(debt).safeTransferFrom(payer, debt, amount);
    }

    function poolV2Callback(
        uint256 amount,
        address poolToken,
        address oraclePool,
        address payer
    ) external override payable {
        IPoolFactory qilin = IPoolFactory(_factory);
        require(
            qilin.pools(poolToken, oraclePool) == msg.sender,
            "poolV2Callback caller is not the pool contract"
        );

        if (poolToken == _wETH && address(this).balance >= amount) {
            IWETH wETH = IWETH(_wETH);
            wETH.deposit{value: amount}();
            wETH.transfer(msg.sender, amount);
        } else {
            if (_routerPay) {
                IERC20(poolToken).safeTransfer(msg.sender, amount);
            }
            else {
                IERC20(poolToken).safeTransferFrom(payer, msg.sender, amount);
            }
        }
    }

    function poolV2RemoveCallback(
        uint256 amount,
        address poolToken,
        address oraclePool,
        address payer
    ) external override {
        IPoolFactory qilin = IPoolFactory(_factory);
        require(
            qilin.pools(poolToken, oraclePool) == msg.sender,
            "poolV2Callback caller is not the pool contract"
        );

        IERC20(msg.sender).safeTransferFrom(payer, msg.sender, amount);
    }

    function createPool(
        address oracleAddress,
        address poolToken
    ) external override {
        IPoolFactory(_factory).createPool(oracleAddress, poolToken);
    }

    function getLsBalance(
        address oracleAddress,
        address poolToken,
        address user
    ) external override view returns (uint256) {
        address pool = getPool(oracleAddress,poolToken);
        return IERC20(pool).balanceOf(user);
    }

    function getLsPrice(
        address oracleAddress,
        address poolToken
    ) external override view returns (uint256) {
        address pool = getPool(oracleAddress,poolToken);
        return IPool(pool).lsTokenPrice();
    }

    function addLiquidity(
        address oracleAddress,
        address poolToken,
        uint256 amount
    ) external override payable {
        IPool pool = IPool(getPool(oracleAddress,poolToken));
        pool.addLiquidity(msg.sender, amount);
    }

    function removeLiquidity(
        address oracleAddress,
        address poolToken,
        uint256 lsAmount,
        uint256 bondsAmount,
        address receipt
    ) external override {
        IPool pool = IPool(getPool(oracleAddress,poolToken));
        pool.removeLiquidity(msg.sender, lsAmount, bondsAmount, receipt);
    }

    function allocContribute(
        address user,
        address tokenAddress,
        uint256 positionAmount
    ) private returns (uint256 contribute) {
        address firstUpper = _upRelation[user];
        contribute = positionAmount.mul(_ownerRate).div(E4);
        if (firstUpper == address(0)) {
            
            _contribute[owner()][tokenAddress] = _contribute[owner()][
                tokenAddress
            ].add(contribute);
            emit AddContribute(owner(),tokenAddress,contribute);
            return contribute;
        }
        uint256 userContribute = positionAmount.mul(_ownerRate - _contributeRate).div(E4);

        uint256 secondCointribute = contribute.sub(userContribute).mul(_secondUpperRate).div(E4);
        _contribute[owner()][tokenAddress] = _contribute[owner()][
            tokenAddress
        ].add(secondCointribute);
        emit AddContribute(owner(),tokenAddress,secondCointribute);


        _contribute[firstUpper][tokenAddress] = _contribute[firstUpper][
            tokenAddress
        ].add(contribute.sub(secondCointribute).sub(userContribute));
        emit AddContribute(firstUpper,tokenAddress,contribute.sub(secondCointribute).sub(userContribute));
        _contribute[user][tokenAddress] = _contribute[user][tokenAddress].add(userContribute);
        emit AddContribute(user,tokenAddress,userContribute);

        return contribute;
    }
    function openPreBill(
        address oracleAddress,
        address poolToken,
        uint8 direction,
        uint16 leverage,
        uint256 position,
        address excutorAddress,
        strategy[] memory strategyDatas) external override payable {
        address poolAddress = getPool(oracleAddress,poolToken);
        _tokenId++;
        IERC20(poolToken).safeTransferFrom(
            msg.sender,
            address(this),
            position
        );
        if (excutorAddress != address(0)) {
            require(IExecutorManager(_legalExecutor).IsLegalExecutor(excutorAddress) == true,"only legal executor can be executor");
            require(msg.value >= _execPreBillAmount,"exec value is not enough");
            (bool success, ) = excutorAddress.call{value: msg.value}(new bytes(0));
            require(success, "ETH transfer failed");
        }
        preBill memory tempBillDate = preBill(
            msg.sender,
            excutorAddress,
            poolAddress,
            direction,
            leverage,
            position
        );
        _preBillData[_tokenId] = tempBillDate;

        emit OpenPreBill(msg.sender,_tokenId,poolAddress,direction,leverage,position,excutorAddress);

        for (uint i = 0; i < strategyDatas.length; i++) {
            if (strategyDatas[i].strategyType != 0) {
                emit StrategySheet(_tokenId,strategyDatas[i].strategyType,strategyDatas[i].value);
            }
        }
    }

    function setStrategy(uint32 tokenId,uint8 billType,strategy[] memory strategyDatas) public {
        if (billType == 1) {
            preBill memory tempBillDate = _preBillData[tokenId];
            require(msg.sender == tempBillDate.owner,"only owner can set strategy");
        } else {
            tokenDate memory tempTokenDate = _tokenData[tokenId];
            require(msg.sender == tempTokenDate.owner,"only owner can set strategy");
        }

        for (uint i = 0; i < strategyDatas.length; i++) {
            if (strategyDatas[i].strategyType != 0) {
                emit StrategySheet(tokenId,strategyDatas[i].strategyType,strategyDatas[i].value);
            }
        }

    }

    function setExecutor(uint32 tokenId,uint8 billType,address executor) external override payable {
        require(billType == 1 || billType == 2,"billType is invalid");
        require(IExecutorManager(_legalExecutor).IsLegalExecutor(executor) == true,"only legal executor can be executor");
        if (billType == 1) {
            preBill memory tempBillDate = _preBillData[tokenId];
            require(msg.sender == tempBillDate.owner,"only owner can set executor");
            tempBillDate.executor = executor;
            _preBillData[tokenId] = tempBillDate;
            require(msg.value >= _execPreBillAmount,"exec value is not enough");
            (bool success, ) = executor.call{value: msg.value}(new bytes(0));
            require(success, "ETH transfer failed");
        } else {
            tokenDate memory tempTokenDate = _tokenData[tokenId];
            require(msg.sender == tempTokenDate.owner,"only owner can set executor");
            require(msg.value >= _execPositionAmount,"exec value is not enough");
            tempTokenDate.executor = executor;
            _tokenData[tokenId] = tempTokenDate;

            (bool success, ) = executor.call{value: msg.value}(new bytes(0));
            require(success, "ETH transfer failed");
        }
        emit SetExecutor(tokenId,executor);
    }

    function execPreBill(uint32 tokenId) external override routerPay {
        preBill memory tempBillDate = _preBillData[tokenId];
        require(msg.sender == tempBillDate.owner || msg.sender == tempBillDate.executor,"not owner or executor to exec the pre bill");
        IPool pool = IPool(tempBillDate.poolAddress);

        uint256 contribute = allocContribute(msg.sender, pool._poolToken(), tempBillDate.position.mul(tempBillDate.leverage));
        uint32 positionId = pool.openPosition(
            tempBillDate.owner,
            tempBillDate.direction,
            tempBillDate.leverage,
            tempBillDate.position.sub(contribute)
        );
        tokenDate memory tempTokenDate = tokenDate(
            tempBillDate.owner,
            address(pool),
            address(0),
            positionId
        );
        _tokenData[tokenId] = tempTokenDate;

        delete _preBillData[tokenId];
        emit ExecPreBill(tokenId,msg.sender);
        emit TokenCreate(tokenId, address(pool), tempBillDate.owner, positionId,address(0));
    }

    function canclePrebill(uint32 tokenId) public {
        preBill memory tempBillDate = _preBillData[tokenId];
        require(msg.sender == tempBillDate.owner,"only owner can cancle bill");
        IPool pool = IPool(tempBillDate.poolAddress);
        IERC20(pool._poolToken()).safeTransfer(msg.sender, tempBillDate.position);
        delete _preBillData[tokenId];
        emit CancleBill(tokenId);
    }

    function openPosition(
        address oracleAddress,
        address poolToken,
        uint8 direction,
        uint16 leverage,
        uint256 position,
        address excutorAddress,
        strategy[] memory strategyDatas
    ) external override payable {
        IPool pool = IPool(getPool(oracleAddress,poolToken));
        _tokenId++;
        uint256 contribute = allocContribute(msg.sender, poolToken, position.mul(leverage));
        
        IERC20(poolToken).safeTransferFrom(
            msg.sender,
            address(this),
            contribute
        );
        uint32 positionId = pool.openPosition(
            msg.sender,
            direction,
            leverage,
            position.sub(contribute)
        );
        if (excutorAddress != address(0)) {
            require(IExecutorManager(_legalExecutor).IsLegalExecutor(excutorAddress) == true,"only legal executor can be executor");
            require(msg.value >= _execPositionAmount,"exec value is not enough");
            (bool success, ) = excutorAddress.call{value: msg.value}(new bytes(0));
            require(success, "ETH transfer failed");
        }
        tokenDate memory tempTokenDate = tokenDate(
            msg.sender,
            address(pool),
            excutorAddress,
            positionId
        );
        _tokenData[_tokenId] = tempTokenDate;

        emit TokenCreate(_tokenId, address(pool), msg.sender, positionId,excutorAddress);

        for (uint i = 0; i < strategyDatas.length; i++) {
            if (strategyDatas[i].strategyType != 0) {
                emit StrategySheet(_tokenId,strategyDatas[i].strategyType,strategyDatas[i].value);
            }
        }
    }

    function addMargin(uint32 tokenId, uint256 margin) external payable override {
        tokenDate memory tempTokenDate = _tokenData[tokenId];
        require(
            tempTokenDate.owner == msg.sender,
            "token owner not match msg.sender"
        );
        IPool(tempTokenDate.poolAddress).addMargin(
            msg.sender,
            tempTokenDate.positionId,
            margin
        );
    }

    function closeAgentPosition(uint32 tokenId) external override {
        tokenDate memory tempTokenDate = _tokenData[tokenId];
        require(
            tempTokenDate.owner == msg.sender || tempTokenDate.executor == msg.sender,
            "token owner not match msg.sender"
        );

        IPool(tempTokenDate.poolAddress).closePosition(
            tempTokenDate.owner,
            tempTokenDate.positionId
        );
        delete _tokenData[tokenId];
    }

    function liquidate(uint32 tokenId, address receipt) external override {
        tokenDate memory tempTokenDate = _tokenData[tokenId];
        require(tempTokenDate.owner != address(0), "tokenId does not exist");
        IPool(tempTokenDate.poolAddress).liquidate(
            msg.sender,
            tempTokenDate.positionId,
            receipt
        );
        delete _tokenData[tokenId];
    }

    function liquidateByPool(address poolAddress, uint32 positionId, address receipt) external override  {
        IPool(poolAddress).liquidate(msg.sender, positionId, receipt);
    }

    function repayLoan(
        address oracleAddress,
        address poolToken,
        uint256 amount,
        address receipt
    ) external override payable {
        address pool = getPool(oracleAddress,poolToken);
        address debtToken = IPool(pool).debtToken();
        IDebt(debtToken).repayLoan(msg.sender, receipt, amount);
    }

    function getPool(
        address oracleAddress,
        address poolToken
    ) public view returns (address) {
        address pool = IPoolFactory(_factory).pools(poolToken, oracleAddress);
        require(pool != address(0), "non-exist pool");
        return pool;
    }

    function exit(uint32 tokenId, address receipt) external override {
        tokenDate memory tempTokenDate = _tokenData[tokenId];
        require(
            tempTokenDate.owner == msg.sender,
            "token owner not match msg.sender"
        );
        IPool(tempTokenDate.poolAddress).exit(
            receipt,
            tempTokenDate.positionId
        );
    }

}