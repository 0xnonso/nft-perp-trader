// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "clones-with-immutable-args/Clone.sol";
import "./interfaces/IClearingHouse.sol";
import "./interfaces/INFTPerpOrder.sol";
import "./utils/Errors.sol";

contract Account is Clone {
    IClearingHouse public constant clearingHouse = IClearingHouse(0xD6508F14F9A031219D3D5b42496B4fC87d86B75d);

    function _onlyAuthorized() internal {
        if(msg.sender != getManager() || msg.sender != getOperator())
            revert Errors.InvalidManagerOrOperator();
    }

    function _onlyOperator() internal {
        if(msg.sender != getOperator())
            revert Errors.InvalidOperator();
    }

    function openPosition(
        IAmm _amm,
        IClearingHouse.Side _side,
        Decimal.decimal memory _quoteAssetAmount,
        Decimal.decimal memory _leverage,
        Decimal.decimal memory _baseAssetAmountLimit
    ) external {
        _onlyAuthorized();
        _approveToCH(_amm.quoteAsset());
        clearingHouse.openPosition(
            _amm,
            _side,
            _quoteAssetAmount,
            _leverage,
            _baseAssetAmountLimit
        );
    }

    function closePosition(
        IAmm _amm, 
        Decimal.decimal memory _quoteAssetAmountLimit
    ) external {
        _onlyAuthorized();
        clearingHouse.closePosition(_amm, _quoteAssetAmountLimit);
    }

    function partialClose(IAmm _amm,
        Decimal.decimal memory _partialCloseRatio,
        Decimal.decimal memory _quoteAssetAmountLimit
    ) external {
        _onlyOperator();
        clearingHouse.partialClose(
            _amm,
            _partialCloseRatio,
            _quoteAssetAmountLimit
        );
    }

    function addMargin(
        IAmm _amm, 
        Decimal.decimal calldata _addedMargin
    ) external {
        _onlyOperator();
        _approveToCH(_amm.quoteAsset());
        clearingHouse.addMargin(_amm, _addedMargin);
    }

    function removeMargin(IAmm _amm, Decimal.decimal calldata _removedMargin) external {
        _onlyOperator();
        clearingHouse.removeMargin(_amm, _removedMargin);
    }

    function withdrawFund(IERC20 token, uint256 amount) external {
        _onlyOperator();
        token.transfer(msg.sender, amount);
    }

    function _approveToCH(IERC20 token) internal {
        if(token.allowance(address(this), address(clearingHouse)) == 0) 
            token.approve(address(clearingHouse), type(uint).max);
    }

    function getManager() public pure returns(address) {
        return _getArgAddress(0x0);
    }
    //msg.sender
    function getOperator() public pure returns(address){
        return _getArgAddress(0x20);
    }
}