// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/INFTPerpOrder.sol";
import "./AccountFactory.sol";
import "./utils/Decimal.sol";
import "./utils/Errors.sol";
import {LibOrder} from "./utils/LibOrder.sol";
import "./utils/Structs.sol";

contract NFTPerpOrder is INFTPerpOrder, Ownable(), ReentrancyGuard(){
    using Decimal for Decimal.decimal;
    using LibOrder for Structs.Order;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    // All open orders
    EnumerableSet.Bytes32Set private openOrders;

    //Account factory implementation contract
    AccountFactory public immutable accountFactory;
    //Fee Manager address
    address private immutable feeManager;
    //Management Fee(paid in eth)
    uint256 public managementFee;
    //mapping(Order Hash/Id -> Order)
    mapping(bytes32 => Structs.Order) public order;
    //mapping(Order Hash/Id -> bool)
    mapping(bytes32 => bool) public orderExecuted;

    constructor(address _accountFactory, address _feeManager){
        accountFactory = AccountFactory(_accountFactory);
        feeManager = _feeManager;
    }


    //
    //      |============================================================================================|
    //      |        BUY/SELL        |     TYPE OF ORDER         |     PRICE LEVEL OF TRIGGER PRICE      |
    //      |============================================================================================|
    //      |          BUY           |    BUY LIMIT ORDER        |    Trigger Price < or = Latest Price  |
    //      |                        |    BUY STOP LOSS ORDER    |    Trigger Price > or = Latest Price  |
    //      |------------------------|---------------------------|---------------------------------------|
    //      |          SELL          |    SELL LIMIT ORDER       |    Trigger Price > or = Latest Price  |
    //      |                        |    SELL STOP LOSS ORDER   |    Trigger Price < or = Latest Price  |
    //      |============================================================================================|
    //
    ///@notice Creates a Market Order(Limit or StopLoss Order). 
    ///        - https://www.investopedia.com/terms/l/limitorder.asp
    ///        - https://www.investopedia.com/articles/stocks/09/use-stop-loss.asp
    ///@param _amm amm
    ///@param _orderType order type
    ///@param _account NFTPerp trader account(optional), account can be address(0) only when creating BUY/SELL limit order
    ///@param _expirationTimestamp order expiry timestamp
    ///@param _triggerPrice trigger/execution price of an order
    ///@param _slippage slippage(0 for any slippage)
    ///@param _leverage leverage, only use when creating a BUY/SELL limit order
    ///@param _quoteAssetAmount quote asset amount, only use when creating a BUY/SELL limit order
    ///@return orderHash
    function createOrder(
        IAmm _amm,
        Structs.OrderType _orderType, 
        address _account,
        uint64 _expirationTimestamp,
        uint256 _triggerPrice,
        Decimal.decimal memory _slippage,
        Decimal.decimal memory _leverage,
        Decimal.decimal memory _quoteAssetAmount
    ) external payable override nonReentrant() returns(bytes32 orderHash){
        // create new account for user if `_account` is empty
        if(_account == address(0)) 
            _account = address(accountFactory.createAccount(msg.sender));

        orderHash = _getOrderHash(_amm, _orderType, _account);
        // checks if order is valid
        _validOrder(_orderType, _expirationTimestamp, _account, orderHash);
        
        Structs.Order storage _order = order[orderHash];
        _order.trigger = _triggerPrice;
        _order.position.amm = _amm;
        _order.position.slippage = _slippage;

        if(_orderType == Structs.OrderType.SELL_LO || _orderType == Structs.OrderType.BUY_LO){
            // Limit Order quote asset amount should be gt zero
            if(_quoteAssetAmount.toUint() == 0)
                revert Errors.InvalidQuoteAssetAmount();

            _order.position.quoteAssetAmount = _quoteAssetAmount;
            _order.position.leverage = _leverage;
            // transfer quote asset amount used to create Limit Order to this contract
            // when order is being executed AMM/CH fees will be deducted from quote asset amount 
            _amm.quoteAsset().transferFrom(
                msg.sender, 
                address(this),
                _quoteAssetAmount.toUint()
            );
        } else {
            int256 positionSize = LibOrder.getPositionSize(_amm, _account);
            // Positon size cannot be equal to zero (No open position)
            if(positionSize == 0) 
                revert Errors.NoOpenPositon();
            // store quote asset amount of user's current open position (open notional)
            _order.position.quoteAssetAmount.d = LibOrder.getPositionNotional(_amm, _account).d;
            // calculate fees to pay to AMM/CH if order was triggered immediately
            // - Fees maybe higher or lower depending on the time of order execution which may incur loses or acquire gains to this contract
            (Decimal.decimal memory toll, Decimal.decimal memory spread) = _amm.calcFee(
                _order.position.quoteAssetAmount,
                positionSize > 0 ? IClearingHouse.Side.SELL : IClearingHouse.Side.BUY
            );
            //transfer fees to this contract
            _amm.quoteAsset().transferFrom(
                msg.sender, 
                address(this),
                toll.addD(spread).toUint()
            );
        }

        uint256 _detail;
        //                             [256 bits]
        //        ===========================================================
        //        |  32 bits     |      160 bits      |       64 bits       |  
        //        -----------------------------------------------------------
        //        | orderType    |      account       | expirationTimestamp |
        //        ===========================================================

        _detail = uint256(_orderType) << 248 | (uint224(uint160(_account)) << 64 | _expirationTimestamp);

        _order.detail = _detail;
        // add order hash to open orders
        openOrders.add(orderHash);
        // trasnsfer fees to Fee-Manager Contract
        _transferFee();

        orderExecuted[orderHash] = false;

        emit OrderCreated(orderHash, _account, address(_amm), uint8(_orderType));
    }

    ///@notice Cancels an Order
    ///@param _orderHash order hash/ID
    function cancelOrder(bytes32 _orderHash) external override nonReentrant(){
        Structs.Order memory _order = order[_orderHash];
        if(!_order.isAccountOwner()) revert Errors.InvalidOperator();
        if(_orderExecuted(_orderHash)) revert Errors.OrderAlreadyExecuted();
        //can only cancel open orders
        if(!_isOpenOrder(_orderHash)) revert Errors.NotOpenOrder();

        //delete order data from mapping and Open Orders array;
        delete order[_orderHash];
        openOrders.remove(_orderHash);
        //refund quote asset deposited
        _order.refundQuoteAsset();
    }

    ///@notice Executes an open order
    ///@param _orderHash order hash/ID
    function executeOrder(bytes32 _orderHash) public override nonReentrant(){
        if(!canExecuteOrder(_orderHash)) revert Errors.CannotExecuteOrder();
        orderExecuted[_orderHash] = true;
        Structs.Order memory _order = order[_orderHash];

        // execute order
        _order.executeOrder();

        //delete order data from Open Orders array;
        openOrders.remove(_orderHash);

        emit OrderExecuted(_orderHash);
    }

    ///@notice Set new management fee
    ///@param _fee new fee amount
    function setManagementFee(uint256 _fee) external onlyOwner(){
        managementFee = _fee;
        emit SetManagementFee(_fee);
    }

    ///@notice Checks if an Order can be executed
    ///@return bool 
    function canExecuteOrder(bytes32 _orderHash) public view override returns(bool){
        return order[_orderHash].canExecuteOrder() && !_orderExecuted(_orderHash);
    }

    ///@notice Fetches all Open Orders
    ///@return bytes[] - array of all Open Orders
    function getOpenOrders() public view returns(bytes32[] memory){
        return openOrders.values();
    }

    //checks if Order is valid during Order creation 
    function _validOrder(
        Structs.OrderType _orderType, 
        uint64 expirationTimestamp, 
        address _account,
        bytes32  _orderHash
    ) internal view {
        // cannot have two orders  with same ID
        if(_isOpenOrder(_orderHash)) revert Errors.OrderAlreadyExists();
        // ensure - expiration timestamp == 0 (no expiry) or not lt current timestamp
        if(expirationTimestamp > 0 && expirationTimestamp < block.timestamp)
            revert Errors.InvalidExpiration();
    }

    function _orderExecuted(bytes32 _orderHash) internal view returns(bool){
        return orderExecuted[_orderHash];
    }

    function _isOpenOrder(bytes32 _orderHash) internal view returns(bool){
        return openOrders.contains(_orderHash);
    }

    function _getOrderHash(IAmm _amm, Structs.OrderType _orderType, address _account) internal pure returns(bytes32){
        return keccak256(
            abi.encodePacked(
                _amm, 
                _orderType, 
                _account
            )
        );
    }

    function _transferFee() internal {
        if(managementFee > 0){
            if(msg.value != managementFee) revert Errors.IncorrectFee();
            (bool sent,) = feeManager.call{value: msg.value}("");
            if(!sent) revert Errors.TransferFailed();
        }
    }

}