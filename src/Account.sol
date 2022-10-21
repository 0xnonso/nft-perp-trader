// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IClearingHouse.sol";
import "./interfaces/INFTPerpOrder.sol";
import "./utils/Errors.sol";

contract Account {
    IClearingHouse public constant clearingHouse = IClearingHouse();

    function _onlyAuthorized() internal {
        if(msg.sender != getManager() || msg.sender != getOperator())
            revert Errors.InvalidManagerOrOperator();
    }

    function openPosition(
        IAmm _amm,
        Side _side,
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
        _onlyAuthorized();
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
        _onlyAuthorized();
        _approveToCH(_amm.quoteAsset());
        clearingHouse.addMargin(_amm, _addedMargin);
    }

    function removeMargin(IAmm _amm, Decimal.decimal calldata _removedMargin) external {
        _onlyAuthorized();
        clearingHouse.removeMargin(_amm, _removedMargin);
    }

    function withdrawFund(IERC20 token, uint256 amount) external {
        _onlyAuthorized();
        token.transfer(msg.sender, amount);
    }

    function _approveToCH(IERC20 token) internal {
        if(token.allowance() == 0) 
            token.approve(clearingHouse, type(uint).max);
    }

    function getManager() public view returns(address) {
        return _getArgAddress(0x0);
    }
    function getOperator() public view returns(address){
        return _getArgAddress(0x20);
    }
}