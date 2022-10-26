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

    IClearingHouse public constant clearingHouse = IClearingHouse(0x23046B6bc1972370A06c15f6d4F589B7607caD5E);

    function executeOrder(Structs.Order memory orderStruct) internal {
        (Structs.OrderType orderType, address account,) = getOrderDetails(orderStruct);

        Decimal.decimal memory quoteAssetAmount = orderStruct.position.quoteAssetAmount;
        Decimal.decimal memory slippage = orderStruct.position.slippage;
        Decimal.decimal memory toll;
        Decimal.decimal memory spread;
        IAmm _amm = orderStruct.position.amm;
        
        if(orderType == Structs.OrderType.BUY_SLO || orderType == Structs.OrderType.SELL_SLO){
            int256 positionSize = getPositionSize(_amm, account);
           
            (toll, spread) = _amm.calcFee(
                quoteAssetAmount,
                positionSize > 0 ? IClearingHouse.Side.SELL : IClearingHouse.Side.BUY
            );
            _amm.quoteAsset().transfer(account, toll.addD(spread).toUint());
            Decimal.decimal memory positionNotional = getPositionNotional(_amm, account);
            if(positionNotional.d > quoteAssetAmount.d){
                Account(account).partialClose(
                    _amm, 
                    quoteAssetAmount.divD(positionNotional).mulScalar(100), 
                    slippage
                );
            } else {
                Account(account).closePosition(_amm, slippage);
            }
            
        } else {
            IClearingHouse.Side side = orderType == Structs.OrderType.BUY_LO ? IClearingHouse.Side.BUY : IClearingHouse.Side.SELL;

            _amm.quoteAsset().transfer(account, quoteAssetAmount.toUint());
            (toll, spread) = _amm.calcFee(
                quoteAssetAmount,
                side
            );
            Decimal.decimal memory _quoteAssetAmount = (quoteAssetAmount.mulD(quoteAssetAmount))
                .divD(quoteAssetAmount.addD(toll.addD(spread)));

            Account(account).openPosition(
                _amm, 
                side, 
                _quoteAssetAmount, 
                orderStruct.position.leverage, 
                slippage
            );
        }
    }

    function isAccountOwner(Structs.Order memory orderStruct) public view returns(bool){
        (, address account ,) = getOrderDetails(orderStruct);
        return msg.sender == Account(account).getOperator();
    }

    function canExecuteOrder(Structs.Order memory orderStruct) public view returns(bool){
        (Structs.OrderType orderType, address account , uint64 expiry) = getOrderDetails(orderStruct);
        uint256 price = orderStruct.position.amm.getSpotPrice().toUint();
        bool _ts = expiry == 0 || block.timestamp < expiry;
        bool _pr;
        bool _op = getPositionSize(orderStruct.position.amm, account) != 0;
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

    function getPositionNotional(IAmm amm, address account) public view returns(Decimal.decimal memory){
         return clearingHouse.getPosition(amm, account).openNotional;
    }
    
    function getOrderDetails(
        Structs.Order memory orderStruct
    ) public pure returns(Structs.OrderType, address, uint64){
        //Todo: make more efficient
        return (
            Structs.OrderType(uint8(orderStruct.detail >> 248)),
            address(uint160(orderStruct.detail << 32 >> 96)),
            uint64(orderStruct.detail << 192 >> 192)
        );  
    }

    // function closePositon(
    //     IAmm _amm, 
    //     address account,
    //     Decimal.decimal memory quoteAssetAmount,
    //     Decimal.decimal memory slip
    // ) internal {
    //     Decimal.decimal memory positionNotional = getPositionNotional(_amm, account);
    //     if(positionNotional.d > quoteAssetAmount.d){
    //         Account(account).partialClose(
    //             _amm, 
    //             quoteAssetAmount.divD(positionNotional).mulScalar(100), 
    //             orderStruct.position.slippage
    //         );
    //     } else {
    //         Account(account).closePosition(_amm, orderStruct.position.slippage);
    //     }

    // }
}