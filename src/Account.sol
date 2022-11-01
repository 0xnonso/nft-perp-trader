// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "clones-with-immutable-args/Clone.sol";
import "./interfaces/IClearingHouse.sol";
import "./interfaces/INFTPerpOrder.sol";

contract Account is Clone {
    IClearingHouse public constant clearingHouse = IClearingHouse(0x23046B6bc1972370A06c15f6d4F589B7607caD5E);

    function _onlyAuthorized() internal {
        require(
            msg.sender == getManager() 
            || msg.sender == getOperator(),
            "Account: InvalidManagerOrOperator"
        );
    }

    function _onlyOperator() internal {
        require(
            msg.sender == getOperator(), 
            "Account: InvalidOperator"
        );
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
        IClearingHouse(getClearingHouse()).openPosition(
            _amm,
            _side,
            _quoteAssetAmount,
            _leverage,
            _baseAssetAmountLimit,
            false
        );
    }

    function closePosition(
        IAmm _amm, 
        Decimal.decimal memory _quoteAssetAmountLimit
    ) external {
        _onlyAuthorized();
        IClearingHouse(getClearingHouse()).closePosition(_amm, _quoteAssetAmountLimit, false);
    }

    function partialClose(IAmm _amm,
        Decimal.decimal memory _partialCloseRatio,
        Decimal.decimal memory _quoteAssetAmountLimit
    ) external {
        _onlyAuthorized();
        IClearingHouse(getClearingHouse()).partialClose(
            _amm,
            _partialCloseRatio,
            _quoteAssetAmountLimit,
            false
        );
    }

    function addMargin(
        IAmm _amm, 
        Decimal.decimal calldata _addedMargin
    ) external {
        _onlyOperator();
        _approveToCH(_amm.quoteAsset());
        IClearingHouse(getClearingHouse()).addMargin(_amm, _addedMargin);
    }

    function removeMargin(IAmm _amm, Decimal.decimal calldata _removedMargin) external {
        _onlyOperator();
        IClearingHouse(getClearingHouse()).removeMargin(_amm, _removedMargin);
    }

    function withdrawFund(IERC20 token, uint256 amount) external {
        _onlyOperator();
        token.transfer(msg.sender, amount);
    }

    function fundAccount(IERC20 token, uint256 amount) external {
        token.transferFrom(msg.sender, address(this), amount);
    }

    function _approveToCH(IERC20 token) internal {
        if(token.allowance(address(this), getClearingHouse()) == 0) 
            token.approve(getClearingHouse(), type(uint).max);
    }

    function getManager() public pure returns(address) {
        return _getArgAddress(0x0);
    }
    //msg.sender
    function getOperator() public pure returns(address){
        return _getArgAddress(0x14);
    }
    function getClearingHouse() public pure returns(address){
        return _getArgAddress(0x28);
    }
}