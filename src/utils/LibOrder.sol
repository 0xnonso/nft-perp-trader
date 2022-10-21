// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../Account.sol";
import "../interfaces/IAmm.sol";
import "../interfaces/IClearingHouse.sol";
import "../interfaces/INFTPerpOrder.sol";

library LibOrder {
    IClearingHouse public constant clearingHouse = IClearingHouse();

    function executeOrder(INFTPerpOrder.Order calldata orderStruct) internal {
        (uint8 orderType, address account, uint64 expiry) = getOrderDetails(orderStruct);
        require(expiry == 0 || block.timestamp < expiry, "LibOrder: CannotExecuteOrder01");
        uint256 price = orderStruct.Position.amm.getMarkPrice().toUint();
        if(orderType == INFTPerpOrder.OrderType.STOP_LO){
            require(price <= orderStruct.trigger, "LibOrder: CannotExecuteOrder02");
            require(getPositionSize(orderStruct.Position.amm, account) != 0, "LibOrder: NoOpenPosition");
            Account(account).closePosition();
        } else {
            uint8 side;
            if(orderType == INFTPerpOrder.OrderType.BUY_LO){
                //BUY LIMIT - price <= target
                require(price <= orderStruct.target, "LibOrder: CannotExecuteOrder03");
            } else {
                //SELL LIMIT - price >= target
                require(price >= orderStruct.target, "LibOrder: CannotExecuteOrder04");
                side = 1;
            }
            orderStruct.Position.amm.quoteAsset().transferFrom(
                address(this),
                account,
                orderStruct.Position.quoteAsset
            );
            Account(account).openPosition(
                orderStruct.Position.amm, 
                side, 
                orderStruct.Position.quoteAssetAmount, 
                orderStruct.Position.leverage, 
                orderStruct.Position.slippage
            );
        }
    }

    function canExecuteOrder(INFTPerpOrder.Order calldata orderStruct) internal returns(bool){
        (uint8 orderType, address account , uint64 expiry) = getOrderDetails(orderStruct);
        uint256 price = orderStruct.Position.amm.getMarkPrice().toUint();
        bool _ts = expiry == 0 || block.timestamp < expiry;
        bool _pr;
        bool _op = getPositionSize(orderStruct.Position.amm, account) != 0;
        if(orderType == INFTPerpOrder.OrderType.STOP_LO){
            _pr = price <= orderStruct.trigger;
        } else {
            _op = true;
            if(orderType == INFTPerpOrder.OrderType.BUY_LO){
                _pr = price <= orderStruct.target;
            } else { _pr = price >= orderStruct.target; }
        }
        return _ts && _pr && _op;
    }

    function getPositionSize(IAmm amm, address account) public view returns(uint256){
         return clearingHouse.getPosition(amm, account).size.toUint();
    }

    function getOrderDetails(INFTPerpOrder.Order calldata orderStruct) internal returns(uint8, address, uint64){}

}