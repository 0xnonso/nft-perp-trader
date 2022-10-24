// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../Account.sol";
import "../interfaces/IAmm.sol";
import "../interfaces/IClearingHouse.sol";
import "../interfaces/INFTPerpOrder.sol";
import "./Decimal.sol";
import "./SignedDecimal.sol";
import "./Structs.sol";

library LibOrder {
    using Decimal for Decimal.decimal;
    using SignedDecimal for SignedDecimal.signedDecimal;

    IClearingHouse public constant clearingHouse = IClearingHouse(0xD6508F14F9A031219D3D5b42496B4fC87d86B75d);

    function executeOrder(Structs.Order calldata orderStruct) public {
        (Structs.OrderType orderType, address account, uint64 expiry) = getOrderDetails(orderStruct);
        require(expiry == 0 || block.timestamp < expiry, "LibOrder: CannotExecuteOrder01");
        uint256 price = orderStruct.position.amm.getMarkPrice().toUint();
        
        if(orderType == Structs.OrderType.BUY_SLO || orderType == Structs.OrderType.SELL_SLO){
            require(getPositionSize(orderStruct.position.amm, account) > 0, "LibOrder: NoOpenPosition");
            if(orderType == Structs.OrderType.BUY_SLO){
                require(price >= orderStruct.trigger, "LibOrder: CannotExecuteOrder02");
            } else {
                require(price <= orderStruct.trigger, "LibOrder: CannotExecuteOrder03");
            }
            Account(account).closePosition(orderStruct.position.amm, orderStruct.position.slippage);
        } else {
            IClearingHouse.Side side;
            if(orderType == Structs.OrderType.BUY_LO){
                //BUY LIMIT - price <= trigger
                require(price <= orderStruct.trigger, "LibOrder: CannotExecuteOrder04");
                side = IClearingHouse.Side.BUY;
            } else {
                //SELL LIMIT - price >= trigger
                require(price >= orderStruct.trigger, "LibOrder: CannotExecuteOrder05");
                side = IClearingHouse.Side.SELL;
            }
            orderStruct.position.amm.quoteAsset().transferFrom(
                address(this),
                account,
                orderStruct.position.quoteAssetAmount.toUint()
            );
            Account(account).openPosition(
                orderStruct.position.amm, 
                side, 
                orderStruct.position.quoteAssetAmount, 
                orderStruct.position.leverage, 
                orderStruct.position.slippage
            );
        }
    }

    function isAccountOwner(Structs.Order calldata orderStruct) public view returns(bool){
        (, address account ,) = getOrderDetails(orderStruct);
        return msg.sender == Account(account).getOperator();
    }

    function canExecuteOrder(Structs.Order calldata orderStruct) public view returns(bool){
        (Structs.OrderType orderType, address account , uint64 expiry) = getOrderDetails(orderStruct);
        uint256 price = orderStruct.position.amm.getMarkPrice().toUint();
        bool _ts = expiry == 0 || block.timestamp < expiry;
        bool _pr;
        bool _op = getPositionSize(orderStruct.position.amm, account) > 0;
        if(orderType == Structs.OrderType.BUY_SLO || orderType == Structs.OrderType.SELL_SLO){
            _pr = orderType == Structs.OrderType.BUY_SLO 
                    ? price >= orderStruct.trigger 
                    : price <= orderStruct.trigger;
        } else {
            _op = true;
            _pr = orderType == Structs.OrderType.BUY_LO 
                    ? price <= orderStruct.trigger 
                    : price >= orderStruct.trigger;
        }
        return _ts && _pr && _op;
    }

    function getPositionSize(IAmm amm, address account) public view returns(int256){
         return clearingHouse.getPosition(amm, account).size.toInt();
    }
    
    function getOrderDetails(
        Structs.Order calldata orderStruct
    ) public pure returns(Structs.OrderType, address, uint64){
        //Todo: make more efficient
        return (
            Structs.OrderType(uint8(orderStruct.detail >> 248)),
            address(uint160(orderStruct.detail << 32 >> 96)),
            uint64(orderStruct.detail << 192 >> 192)
        );  
    }
}