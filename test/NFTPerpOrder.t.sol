// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/AccountFactory.sol";
import "../src/FeeManager.sol";
import "../src/NFTPerpOrder.sol";
import "../src/NFTPerpOrderResolver.sol";
import "./utils/Utilities.sol";


contract NFTPerpOrderTest is Test {
    using Decimal for Decimal.decimal;

    Utilities internal utils;
    address payable[] internal users;

    AccountFactory internal accountFactory;
    FeeManager internal feeManager;
    NFTPerpOrder internal nftPerpOrder;
    NFTPerpOrderResolver internal gelResolver;
    address internal constant clearingHouse = 0x23046B6bc1972370A06c15f6d4F589B7607caD5E;

    //hardcode for testing
    IAmm internal constant MOON_BIRD_AMM = IAmm(0xb50BedcA449f7F9980c3606e4Fe1FB8F48C6A228);
    uint256 internal mockTriggerPrice_1;
    uint256 internal mockTriggerPrice_2;

    string ARB_RPC_URL = vm.envString("ARB_RPC_URL");

    /*//////////////////////////////////////////////////////////////
                                  SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public {

        vm.createSelectFork(ARB_RPC_URL);
        address _ops = 0xB3f5503f93d5Ef84b06993a1975B9D21B962892F;
        address _taskTreasury = 0xB2f34fd4C16e656163dADFeEaE4Ae0c1F13b140A;

        utils = new Utilities();

        address nftPerpOrderAddress = utils.predictContractAddress(address(this), 3);

        accountFactory = new AccountFactory(
            nftPerpOrderAddress,
            clearingHouse
        );
        gelResolver = new NFTPerpOrderResolver(
            nftPerpOrderAddress, 
            _ops
        );
        feeManager = new FeeManager(
            address(gelResolver), 
            _taskTreasury
        );
        nftPerpOrder = new NFTPerpOrder(
            address(accountFactory),
            address(feeManager)
        );
        uint256 currentPrice = MOON_BIRD_AMM.getSpotPrice().toUint();
        mockTriggerPrice_1 = currentPrice + 1e18;
        mockTriggerPrice_2 = currentPrice - 1e18;
        
        deal(address(MOON_BIRD_AMM.quoteAsset()), address(this), 50e18);
        //Fund gelato tasks
        deal(address(feeManager), 1e18);
        feeManager.fundGelatoTasksETH(1e18);
    }

    /*//////////////////////////////////////////////////////////////
                                  ORDER TEST
    //////////////////////////////////////////////////////////////*/
    
    function testCreateLO() public {
        _approve();
        // create account
        Account _account =  accountFactory.createAccount(address(this));
        // create buy limit order
        bytes32 _orderHash = _createOrder(
            MOON_BIRD_AMM, 
            Structs.OrderType.BUY_LO, 
            address(_account), 
            0, 
            mockTriggerPrice_1, 
            0, 
            2e18, 
            2e18
        );
        _executeOrder(_orderHash);
        // expect position notional > 0
        assert(IClearingHouse(clearingHouse).getPosition(MOON_BIRD_AMM, address(_account)).openNotional.toUint() > 0);
    }
    function testExecuteOrderBeforeExpiryLO() public {
         _approve();
        gelResolver.startTask();
        // create Order
        bytes32 _orderHash = _createOrder(
            MOON_BIRD_AMM, 
            Structs.OrderType.BUY_LO, 
            address(0), 
            uint64(block.timestamp) + 5 minutes, 
            mockTriggerPrice_1, 
            0, 
            2e18, 
            2e18
        );
        vm.warp(block.timestamp + 6 minutes);
        // expect tx reverts
        vm.expectRevert(Errors.CannotExecuteOrder.selector);
        //execute order after expiry
        _executeOrder(_orderHash);
    }
    
    function testCancelExecutedOrderLO() public {
        _approve();
        // create order
        bytes32 _orderHash = _createOrder(
            MOON_BIRD_AMM, 
            Structs.OrderType.BUY_LO, 
            address(0), 
            uint64(block.timestamp) + 25 minutes, 
            mockTriggerPrice_1, 
            0, 
            2e18, 
            2e18
        );
        vm.warp(block.timestamp + 24 minutes);
        // execute order
        _executeOrder(_orderHash);
        // expect tx to revert
        vm.expectRevert(Errors.OrderAlreadyExecuted.selector);
        // cancel executed order
        _cancelOrder(_orderHash);
    }
    
    function testDuplicateOrder() public {
        _approve();
        // create account
        Account _account =  accountFactory.createAccount(address(this));
        //1st Order
        _createOrder(
            MOON_BIRD_AMM, 
            Structs.OrderType.BUY_LO, 
            address(_account), 
            uint64(block.timestamp) + 5 minutes, 
            mockTriggerPrice_1, 
            0, 
            2e18, 
            2e18
        );
        // expect tx to revert 
        vm.expectRevert(Errors.OrderAlreadyExists.selector);
        //duplicate order
        _createOrder(
            MOON_BIRD_AMM, 
            Structs.OrderType.BUY_LO, 
            address(_account), 
            uint64(block.timestamp) + 50 minutes, 
            mockTriggerPrice_1, 
            0, 
            2e18, 
            1e18
        );
    }

    function testNoOpenPosition1() public {
        _approve();
        // expect tx to revert
        vm.expectRevert(Errors.NoOpenPositon.selector);
        // create order
        _createOrder(
            MOON_BIRD_AMM, 
            Structs.OrderType.BUY_SLO, 
            address(0), 
            uint64(block.timestamp) + 5 minutes, 
            mockTriggerPrice_1, 
            0, 
            0, 
            0
        );
    }

    function testPartialClose() public {
        // create account
        Account _account =  accountFactory.createAccount(address(this));
        // transfer quote asset to account and open position
       _transferQuoteAsset(MOON_BIRD_AMM, _account, 3e18);
        // open position
        _openAccountPosition(_account, MOON_BIRD_AMM, IClearingHouse.Side.BUY, 1e18, 2e18, 0);
        // approve nft perp order contract
        _approve();
        // create order
        bytes32 _orderHash = _createOrder(
            MOON_BIRD_AMM, //amm
            Structs.OrderType.SELL_SLO, //ordertype
            address(_account), //account
            0, //expiration timestamp
            mockTriggerPrice_1, //trigger price
            0, //slippage
            0, //leverage
            0  //qAmt
        );
        // increase position size
        _openAccountPosition(_account, MOON_BIRD_AMM, IClearingHouse.Side.BUY, 1e18, 2e18, 0);
        // execute order
        _executeOrder(_orderHash);
        // ensure position is partially closed
        assert(IClearingHouse(clearingHouse).getPosition(MOON_BIRD_AMM, address(_account)).openNotional.toUint() > 0);
    }

    function testFullyClosePostion() public {
        // create account
        Account _account =  accountFactory.createAccount(address(this));
        // transfer quote asset to account and open position
        _transferQuoteAsset(MOON_BIRD_AMM, _account, 2e18);
        // open position
        _openAccountPosition(_account, MOON_BIRD_AMM, IClearingHouse.Side.BUY, 1e18, 2e18, 0);
        // approve nft perp order contract
        _approve();
        // create order
        bytes32 _orderHash = _createOrder(
            MOON_BIRD_AMM, //amm
            Structs.OrderType.SELL_SLO, //ordertype
            address(_account), //account
            0, //expiration timestamp
            mockTriggerPrice_1, //trigger price
            0, //slippage
            0, //leverage
            0  //qAmt
        );
        // execute order
        _executeOrder(_orderHash);
        // ensure position is fully closed
        assert(IClearingHouse(clearingHouse).getPosition(MOON_BIRD_AMM, address(_account)).openNotional.toUint() == 0);
    }

    function testInvalidQuoteAssetAmountLO() public {
        // create account
        Account _account =  accountFactory.createAccount(address(this));
        _approve();
        // expect tx to revert
        vm.expectRevert(Errors.InvalidQuoteAssetAmount.selector);
        // create order
        _createOrder(
            MOON_BIRD_AMM, //amm
            Structs.OrderType.BUY_LO, //ordertype
            address(_account), //account
            0, //expiration timestamp
            mockTriggerPrice_1, //trigger price
            0, //slippage
            0, //leverage
            0  //qAmt
        );
    }

    /*//////////////////////////////////////////////////////////////
                                  HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _createOrder(
        IAmm _amm, 
        Structs.OrderType _orderType, 
        address _account, 
        uint64 _expirationTimestamp, 
        uint256 _triggerPrice, 
        uint256 slippage, 
        uint256 leverage, 
        uint256 qAmt
    ) internal returns(bytes32){
        Decimal.decimal memory _slippage;
        _slippage.d = slippage;
        Decimal.decimal memory _leverage;
        _leverage.d = leverage;
        Decimal.decimal memory _quoteAssetAmount;
        _quoteAssetAmount.d = qAmt;

        return nftPerpOrder.createOrder(
            _amm, 
            _orderType, 
            _account, 
            _expirationTimestamp, 
            _triggerPrice, 
            _slippage, 
            _leverage, 
            _quoteAssetAmount
        );
    }
    function _openAccountPosition(
        Account _account,
        IAmm _amm,
        IClearingHouse.Side _side,
        uint256 _quoteAssetAmt,
        uint256 _leverage,
        uint256 _slippage
    ) internal {
        Decimal.decimal memory quoteAssetAmount;
        quoteAssetAmount.d = _quoteAssetAmt;
        Decimal.decimal memory leverage;
        leverage.d = _leverage;
        Decimal.decimal memory slippage;
        slippage.d = _slippage;

        _account.openPosition(_amm, _side, quoteAssetAmount, leverage, slippage);
    }
    function _fullyCloseAccountPosition(Account _account, IAmm _amm, uint256 _slippage) internal {
        Decimal.decimal memory slippage;
        slippage.d = _slippage;
        _account.closePosition(_amm, slippage);
    }
    function _transferQuoteAsset(IAmm _amm, Account _account, uint256 _amount) internal {
         _amm.quoteAsset().transfer(
            address(_account),
            _amount
        );
    }
    function _approve() internal {
        MOON_BIRD_AMM.quoteAsset().approve(address(nftPerpOrder), type(uint).max);
    }
    function _calculateAMMFees(uint256 quoteAssetAmount, IClearingHouse.Side _side) internal view returns(uint256) {
        Decimal.decimal memory _quoteAssetAmount;
        _quoteAssetAmount.d = quoteAssetAmount;
        (Decimal.decimal memory toll, Decimal.decimal memory spread) = MOON_BIRD_AMM.calcFee(
            _quoteAssetAmount,
            _side
        );
        return toll.addD(spread).toUint();
    }
    function _cancelOrder(bytes32 _orderHash) internal {
        nftPerpOrder.cancelOrder(_orderHash);
    }
    function _executeOrder(bytes32 _orderHash) internal {
        nftPerpOrder.executeOrder(_orderHash);
    }
}
