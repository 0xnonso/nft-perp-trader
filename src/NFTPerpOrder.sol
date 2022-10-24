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
    // Declare a set state variable
    EnumerableSet.Bytes32Set private openOrders;

    //Account factory implementation contract
    AccountFactory public immutable accountFactory;
    //Fee Manager address
    address private immutable feeManager;
    uint256 public managementFee;

    mapping(bytes32 => Structs.Order) public order;
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
    ///@notice Creates a Market Order. 
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
        orderHash = _getOrderHash(_amm, _orderType, _account);
        _validOrder(_orderType, _expirationTimestamp, _account);
        Structs.Order storage _order = order[orderHash];
        _order.trigger = _triggerPrice;
        _order.position.amm = _amm;
        _order.position.slippage = _slippage;
        if(_orderType == Structs.OrderType.SELL_LO || _orderType == Structs.OrderType.BUY_LO){
            if(_quoteAssetAmount.toUint() == 0)
                revert Errors.InvalidQuoteAssetAmount();
            if(_account == address(0)) 
                _account = address(accountFactory.createAccount(msg.sender));
            _order.position.quoteAssetAmount = _quoteAssetAmount;
            _order.position.leverage = _leverage;
            _amm.quoteAsset().transferFrom(
                msg.sender, 
                address(this),
                _quoteAssetAmount.toUint()
            );
        } else {
            // Positon size cannot be less than zero
            if(LibOrder.getPositionSize(_amm, _account) == 0) 
                revert Errors.NoOpenPositon();
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
        openOrders.add(orderHash);
        //_transferFee();

        emit OrderCreated(orderHash, _account, address(_amm), uint8(_orderType));
    }

    ///@notice Cancels an Order
    ///@param _orderHash order hash/ID
    function cancelOrder(bytes32 _orderHash) external override nonReentrant(){
        if(!order[_orderHash].isAccountOwner()) revert Errors.InvalidOperator();
        if(orderExecuted[_orderHash]) revert Errors.OrderAlreadyExecuted();
        if(!openOrders.contains(_orderHash)) revert Errors.NotOpenOrder();
        delete order[_orderHash];
        //remove oreder from array open orders
        openOrders.remove(_orderHash);
    }

    ///@notice Executes an open order
    ///@param _orderHash order hash/ID
    function executeOrder(bytes32 _orderHash) public override nonReentrant(){
        if(!canExecuteOrder(_orderHash)) revert Errors.CannotExecuteOrder();
        orderExecuted[_orderHash] = true;
        order[_orderHash].executeOrder();
        //delete order data from mapping and array;
        delete order[_orderHash];
        openOrders.remove(_orderHash);

        emit OrderExecuted(_orderHash);
    }

    ///@notice Set new management fee
    ///@param _fee new fee amount
    function setManagementFee(uint256 _fee) external onlyOwner(){
        managementFee = _fee;
        emit SetManagementFee(_fee);
    }

    function canExecuteOrder(bytes32 _orderHash) public view override returns(bool){
        return order[_orderHash].canExecuteOrder() && !orderExecuted[_orderHash];
    }
    function getOpenOrders() public view returns(bytes32[] memory){
        return openOrders.values();
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

    function _validOrder(Structs.OrderType _orderType, uint64 expirationTimestamp, address _account) internal view {
        if(expirationTimestamp > 0 && expirationTimestamp < block.timestamp)
            revert Errors.InvalidExpiration();

        if((_orderType == Structs.OrderType.SELL_SLO || _orderType == Structs.OrderType.BUY_SLO)
            && (_account == address(0) || !accountFactory.validAccount(_account))
        ) revert Errors.InvalidAccount();
    }

    function _transferFee() internal {
        if(managementFee > 0){
            if(msg.value != managementFee) revert Errors.IncorrectFee();
            (bool sent,) = feeManager.call{value: msg.value}("");
            if(!sent) revert Errors.TransferFailed();
        }
    }

}