// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/FeeManager.sol";
import "../src/NFTPerpOrder.sol";
import "../src/interfaces/IDelegateApproval.sol";
import "../src/interfaces/IClearingHouse.sol";
import "./utils/Utilities.sol";


contract NFTPerpOrderTest is Test {
    using Decimal for Decimal.decimal;

    Utilities internal utils;
    address payable[] internal users;

    FeeManager internal feeManager;
    NFTPerpOrder internal nftPerpOrder;

    IDelegateApproval internal constant delegateApproval = IDelegateApproval(0xDBaBBC228D01f7953526964C95bA06073A3c8b66);
    IClearingHouse internal constant clearingHouse = IClearingHouse(0x24D9D8767385805334ebd35243Dc809d0763b891);

    //hardcode for testing
    IAmm internal constant _AMM = IAmm(0x31318AFBb9B843B9583F242CD7795e7706258798);
    address internal constant prankster = 0xdE79aAA2f54160b45EF69E1C4b8Fc4c290cd5B88;
    uint256 internal mockTriggerPrice_1;
    uint256 internal mockTriggerPrice_2;

    string ARB_RPC_URL = vm.envString("ARB_RPC_URL");

    /*//////////////////////////////////////////////////////////////
                                  SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public {
        vm.createSelectFork(ARB_RPC_URL);
        

        feeManager = new FeeManager();
        nftPerpOrder = new NFTPerpOrder(
            address(clearingHouse),
            address(feeManager)
        );
        uint256 currentPrice = _AMM.getMarkPrice().toUint();
        mockTriggerPrice_1 = currentPrice + 1e18;
        mockTriggerPrice_2 = currentPrice - 1e18;

        console.log(currentPrice);
        console.log(mockTriggerPrice_1);
        console.log(mockTriggerPrice_2);
        
        deal(address(_AMM.quoteAsset()), prankster, 50e18);

        // gelResolver.startTask();

        //Fund gelato tasks
        // deal(address(feeManager), 1e18);
        // feeManager.fundGelatoTasksETH(1e18);

        vm.startPrank(prankster);
        // approve to clearing house
        _approveToCH(_AMM);
        // delegate position
        _delegatePosition(true);
        _delegatePosition(false);
        //stop prank
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                  ORDER TEST
    //////////////////////////////////////////////////////////////*/
    
    function testCreateBuyLO() public {
        //start prank
        vm.startPrank(prankster);
        address _account = prankster;
        // No open position
        assert(
            clearingHouse.getPosition(
                _AMM, 
                _account
            ).openNotional.toUint() == 0
        );

        // create buy limit order
        bytes32 _orderHash = _createOrder(
            _AMM, 
            Structs.OrderType.BUY_LO, 
            0, 
            mockTriggerPrice_1, 
            0, 
            2e18, 
            4e18
        );
        //stop prank
        vm.stopPrank();

        vm.rollFork(block.number + 1);

        // _executeOrder(_orderHash);
        console.log(clearingHouse.getPosition(_AMM, _account).openNotional.toUint());

        // expect position notional > 0
        assertTrue(
            clearingHouse.getPosition(
                _AMM, 
                _account
            ).openNotional.toUint() != 0, "NO OPEN POSITION" 
        );
    }

    function testCreateSellLO() public {
        //start prank
        vm.startPrank(prankster);
        address _account = prankster;
        // No open position
        assert(
            clearingHouse.getPosition(
                _AMM, 
                _account
            ).openNotional.toUint() == 0
        );

        // delegate position
        _delegatePosition(true);
        // create buy limit order
        bytes32 _orderHash = _createOrder(
            _AMM, 
            Structs.OrderType.SELL_LO, 
            0, 
            mockTriggerPrice_2, 
            0, 
            2e18, 
            2e18
        );
        //stop prank
        vm.stopPrank();

        vm.rollFork(block.number + 1);

        // _executeOrder(_orderHash);
        console.log(clearingHouse.getPosition(_AMM, _account).openNotional.toUint());

        // expect position notional > 0
        assertTrue(
            clearingHouse.getPosition(
                _AMM, 
                _account
            ).openNotional.toUint() != 0, "NO OPEN POSITION" 
        );
    }

    function testCreateSellSLO() public {
        //start prank
        vm.startPrank(prankster);
        address _account = prankster;

        // open position
        _openPosition(IClearingHouse.Side.SELL, 2e18, 0);
        console.log(clearingHouse.getPosition(_AMM, _account).openNotional.toUint());

        // create buy limit order
        bytes32 _orderHash = _createOrder(
            _AMM, 
            Structs.OrderType.SELL_SLO, 
            0, 
            mockTriggerPrice_1, 
            0, 
            0, 
            type(uint256).max
        );
        //stop prank
        vm.stopPrank();

        vm.rollFork(block.number + 1);

        //_executeOrder(_orderHash);
        console.log(clearingHouse.getPosition(_AMM, _account).openNotional.toUint());

        // expect position notional > 0
        assertTrue(
            clearingHouse.getPosition(
                _AMM, 
                _account
            ).openNotional.toUint() == 0, "POSITION NOT CLOSED" 
        );
    }

    function testCreateBuySLO() public {
        //start prank
        vm.startPrank(prankster);
        address _account = prankster;
        // open position
        _openPosition(IClearingHouse.Side.BUY, 2e18, 0);
    
        // create buy limit order
        bytes32 _orderHash = _createOrder(
            _AMM, 
            Structs.OrderType.BUY_SLO, 
            0, 
            mockTriggerPrice_2, 
            0, 
            0, 
            type(uint256).max
        );
        //stop prank
        vm.stopPrank();

        vm.rollFork(block.number + 1);

        //_executeOrder(_orderHash);
        console.log(clearingHouse.getPosition(_AMM, _account).openNotional.toUint());

        // expect position notional > 0
        assertTrue(
            clearingHouse.getPosition(
                _AMM, 
                _account
            ).openNotional.toUint() == 0, "POSITION NOT CLOSED" 
        );
    }
    
    

    // function testExecuteOrderBeforeExpiryLO() public {
    //      _approve();
    //     gelResolver.startTask();
    //     // create Order
    //     bytes32 _orderHash = _createOrder(
    //         _AMM, 
    //         Structs.OrderType.BUY_LO, 
    //         address(0), 
    //         uint64(block.timestamp) + 5 minutes, 
    //         mockTriggerPrice_1, 
    //         0, 
    //         2e18, 
    //         2e18
    //     );
    //     vm.warp(block.timestamp + 6 minutes);
    //     // expect tx reverts
    //     vm.expectRevert(Errors.CannotExecuteOrder.selector);
    //     //execute order after expiry
    //     _executeOrder(_orderHash);
    // }
    
    function testCancelExecutedOrderLO() public {
        vm.startPrank(prankster);
        // create order
        bytes32 _orderHash = _createOrder(
            _AMM, 
            Structs.OrderType.BUY_LO, 
            uint64(block.timestamp) + 25 minutes, 
            mockTriggerPrice_1, 
            0, 
            2e18, 
            2e18
        );
        vm.stopPrank();

        vm.warp(block.timestamp + 24 minutes);
        // execute order
        _executeOrder(_orderHash);
        // expect tx to revert
        vm.expectRevert(Errors.OrderAlreadyFulfilled.selector);

        vm.startPrank(prankster);
        // cancel executed order
        _cancelOrder(_orderHash);
        vm.stopPrank();
    }
    
    function testDuplicateOrder() public {
        //1st Order
        _createOrder(
            _AMM, 
            Structs.OrderType.BUY_LO, 
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
            _AMM, 
            Structs.OrderType.BUY_LO,
            uint64(block.timestamp) + 50 minutes, 
            mockTriggerPrice_2, 
            0, 
            1e18, 
            1e18
        );
    }

    function testNoOpenPosition() public {
        // expect tx to revert
        vm.expectRevert(Errors.NoOpenPositon.selector);
        // create order
        _createOrder(
            _AMM, 
            Structs.OrderType.BUY_SLO, 
            uint64(block.timestamp) + 5 minutes, 
            mockTriggerPrice_1, 
            0, 
            2e18, 
            2e18
        );
    }

//     function testPartialClose() public {
//         // create account
//         Account _account =  accountFactory.createAccount(address(this));
//         // transfer quote asset to account and open position
//        _transferQuoteAsset(_AMM, _account, 3e18);
//         // open position
//         _openAccountPosition(_account, _AMM, IClearingHouse.Side.BUY, 1e18, 2e18, 0);
//         // approve nft perp order contract
//         _approve();
//         // create order
//         bytes32 _orderHash = _createOrder(
//             _AMM, //amm
//             Structs.OrderType.SELL_SLO, //ordertype
//             address(_account), //account
//             0, //expiration timestamp
//             mockTriggerPrice_1, //trigger price
//             0, //slippage
//             0, //leverage
//             0  //qAmt
//         );
//         // increase position size
//         _openAccountPosition(_account, _AMM, IClearingHouse.Side.BUY, 1e18, 2e18, 0);
//         // execute order
//         _executeOrder(_orderHash);
//         console.log(IClearingHouse(clearingHouse).getPosition(_AMM, address(_account)).margin.toUint());
//         // ensure position is partially closed
//         //assert(IClearingHouse(clearingHouse).getPosition(_AMM, address(_account)).openNotional.toUint() > 0);
//     }

//     // function testFullyClosePostion() public {
//     //     // create account
//     //     Account _account =  accountFactory.createAccount(address(this));
//     //     // transfer quote asset to account and open position
//     //     _transferQuoteAsset(_AMM, _account, 2e18);
//     //     // open position
//     //     _openAccountPosition(_account, _AMM, IClearingHouse.Side.BUY, 1e18, 2e18, 0);
//     //     // approve nft perp order contract
//     //     _approve();
//     //     // create order
//     //     bytes32 _orderHash = _createOrder(
//     //         _AMM, //amm
//     //         Structs.OrderType.SELL_SLO, //ordertype
//     //         address(_account), //account
//     //         0, //expiration timestamp
//     //         mockTriggerPrice_1, //trigger price
//     //         0, //slippage
//     //         0, //leverage
//     //         0  //qAmt
//     //     );
//     //     // execute order
//     //     _executeOrder(_orderHash);
//     //     // ensure position is fully closed
//     //     assert(IClearingHouse(clearingHouse).getPosition(_AMM, address(_account)).openNotional.toUint() == 0);
//     // }

    function testInvalidQuoteAssetAmountLO() public {
        // expect tx to revert
        vm.expectRevert(Errors.InvalidQuoteAssetAmount.selector);
        // create order
        _createOrder(
            _AMM, //amm
            Structs.OrderType.BUY_LO, //ordertype
            0, //expiration timestamp
            mockTriggerPrice_1, //trigger price
            0, //slippage
            1, //leverage
            0  //qAmt
        );
    }

//     /*//////////////////////////////////////////////////////////////
//                                   HELPER FUNCTIONS
//     //////////////////////////////////////////////////////////////*/
    function _createOrder(
        IAmm _amm, 
        Structs.OrderType _orderType,
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
            _expirationTimestamp, 
            _triggerPrice, 
            _slippage, 
            _leverage, 
            _quoteAssetAmount
        );
    }
    function _openPosition(IClearingHouse.Side _side, uint256 quoteAssetAmount, uint256 slippage) internal {
        Decimal.decimal memory _quoteAssetAmount;
        _quoteAssetAmount.d = quoteAssetAmount;
        Decimal.decimal memory _slippage;
        _slippage.d = slippage;

        clearingHouse.openPosition(
            _AMM, 
            _side, 
            _quoteAssetAmount, 
            Decimal.decimal(2e18),
            _slippage
        );
    }
    function _closePosition(uint256 slippage) internal {
        Decimal.decimal memory _slippage;
        _slippage.d = slippage;
        clearingHouse.closePosition(_AMM, _slippage);
    }
    function _cancelOrder(bytes32 _orderHash) internal {
        nftPerpOrder.cancelOrder(_orderHash);
    }
    function _executeOrder(bytes32 _orderHash) internal {
        nftPerpOrder.fulfillOrder(_orderHash);
    }
    function _approveToCH(IAmm _amm) internal {
        _amm.quoteAsset().approve(address(clearingHouse), type(uint).max);
    }
    function _delegatePosition(bool _open) internal {
        uint8 _action = _open 
            ? 1
            : 2;
        delegateApproval.approve(address(nftPerpOrder), _action);
    }
}
