// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;
import { Decimal } from "../utils/Decimal.sol";
import { SignedDecimal } from "../utils/SignedDecimal.sol";
import { IAmm } from "./IAmm.sol";

interface INFTPerpOrder {
    enum OrderType {SELL_LO, BUY_LO, STOP_LO}

    struct Position{
        IAmm amm;
        Decimal.decimal quoteAssetAmount;
        Decimal.decimal slippage;
        Decimal.decimal leverage;
    }

    struct Order{
        // ordertype, account, expirationTimestamp
        uint256 detail;
        uint256 trigger;
        Position positon;
    }

    event OrderCreated(bytes32 indexed orderHash, address indexed account, address indexed amm, uint8 orderType);
    event OrderExecuted(bytes32 indexed orderhash);

    function createAccount(
        IAmm _amm,
        OrderType _orderType, 
        address _account,
        uint64 _expirationTimestamp,
        uint256 _triggerPrice,
        Decimal.decimal memory _slippage,
        Decimal.decimal memory _leverage,
        Decimal.decimal memory _quoteAssetAmount
    ) external;

    function executeOrder(bytes32 _orderHash) external;

    function canExecuteOrder(bytes32 _orderhash) external view returns(bool);

}