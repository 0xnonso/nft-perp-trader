// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/INFTPerpOrder.sol";
import "./AccountFactory.sol";
import "./utils/Decimal.sol";
import "./utils/Errors.sol";
import "./utils/LibOrder.sol";

contract NFTPerpOrder {
    using Decimal for Decimal.decimal;
    using LibOrder for INFTPerpOrder.Order;

    AccountFactory public immutable accountFactory;

    mapping(bytes32 => INFTPerpOrder.Order) public order;
    mapping(bytes32 => bool) public orderExecuted;
    bytes32[] private openOrders;

    constructor(address _accountFactory){
        accountFactory = AccountFactory(_accountFactory);
    }

    function createOrder(
        IAmm _amm,
        INFTPerpOrder.OrderType _orderType, 
        address _account,
        uint64 _expirationTimestamp,
        uint256 _triggerPrice,
        Decimal.decimal memory _slippage,
        Decimal.decimal memory _leverage,
        Decimal.decimal memory _quoteAssetAmount
    ) external {
        bytes32 orderHash = _getOrderHash(_amm, _orderType, _account);
        _validOrder(_orderType, _expirationTimestamp, _account);
        INFTPerpOrder.Order storage _order = order[orderHash];
        _order.trigger = _triggerPrice;
        _order.position.amm = _amm;
        _order.position.slippage = _slippage;
        if(_orderType != INFTPerpOrder.OrderType.STOP_LO){
            if(_account == address(0)) 
                _account = address(accountFactory.createAccount(msg.sender, address(this)));
            _order.position.quoteAssetAmount = _quoteAssetAmount;
            _order.position.leverage = _leverage;
            _amm.quoteAsset().transferFrom(
                msg.sender, 
                address(this),
                _quoteAssetAmount.toUint()
            );
        } else {
            if(LibOrder.getPositionSize(_amm, _account) == 0) 
                revert Errors.NoOpenPositon();
        }
        uint256 _detail;
        _order.detail = _detail;
        openOrders.push(orderHash);
        emit INFTPerpOrder.OrderCreated(orderHash, _account, address(_amm), uint8(_orderType));
    }

    function executeOrder(bytes32 _orderHash) public {
        if(!canExecuteOrder(_orderHash)) revert Errors.CannotExecuteOrder();
        orderExecuted[_orderHash] = true;
        order[_orderHash].executeOrder();
        //delete order data from mapping and array;
        //

        emit INFTPerpOrder.OrderExecuted(_orderHash);
    }

    function canExecuteOrder(bytes32 _orderHash) public view returns(bool){
        return order[_orderHash].canExecuteOrder() && !orderExecuted[_orderHash];
    }
    function getOpenOrders() public view returns(bytes32[] memory){
        return openOrders;
    }

    function _getOrderHash(IAmm _amm, OrderType _orderType, address _account) internal {}
    function _validOrder(INFTPerpOrder.OrderType _orderType, uint64 expirationTimestamp, address _account) internal {
        if(expirationTimestamp > 0 && expirationTimestamp < block.timestamp)
            revert Errors.InvalidExpiration();

        if(_orderType == INFTPerpOrder.OrderType.STOP_LO 
            && (_account == address(0) || !accountFactory.validAccount(_account))
        ) revert Errors.InvalidAccount();
    }

}