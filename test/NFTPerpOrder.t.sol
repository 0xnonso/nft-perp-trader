// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/AccountFactory.sol";
import "../src/FeeManager.sol";
import "../src/NFTPerpOrder.sol";
import "../src/NFTPerpOrderResolver.sol";
import "./utils/Utilities.sol";


contract NFTPerpOrderTest is Test {
    using Decimal for Decimal.decimal;

    Utilities internal utils;
    address payable[] internal users;

    AccountFactory internal accountFactory;
    FeeManager internal feeManager;
    NFTPerpOrder internal nftPerpOrder;
    NFTPerpOrderResolver internal gelResolver;

    string arbMainnetKey = "";

    function setUp() public {
        vm.createSelectFork(arbMainnetKey);
        address _ops = 0xB3f5503f93d5Ef84b06993a1975B9D21B962892F;
        address _taskTreasury = 0xB2f34fd4C16e656163dADFeEaE4Ae0c1F13b140A;

        utils = new Utilities();

        address nftPerpOrderAddress = utils.predictContractAddress(address(this), 3);

        accountFactory = new AccountFactory(
            nftPerpOrderAddress
        );
        gelResolver = new NFTPerpOrderResolver(
            nftPerpOrderAddress, 
            payable(_ops)
        );
        feeManager = new FeeManager(
            address(gelResolver), 
            payable(_taskTreasury)
        );
        nftPerpOrder = new NFTPerpOrder(
            address(accountFactory),
            address(feeManager)
        );
    }

    function testCreateOrder() public {
        IAmm _amm = IAmm(0xc55647C8030AD34E4162562e0fD803F813381E8B);
        Structs.OrderType _orderType = Structs.OrderType.BUY_LO;
        address _account = address(0);
        uint64 _expirationTimestamp = uint64(block.timestamp + 25 minutes);
        uint256 _triggerPrice;
        Decimal.decimal memory _slippage = Decimal.decimal(0);
        Decimal.decimal memory _leverage = Decimal.decimal(1e18);
        Decimal.decimal memory _quoteAssetAmount = Decimal.decimal(1e17);

        address user = 0x36dd48f087E63c3253510A0b916F225Dc4d462a2;
        vm.prank(user);

        _amm.quoteAsset().approve(address(nftPerpOrder), type(uint).max);

        nftPerpOrder.createOrder(
            _amm, 
            _orderType, 
            _account, 
            _expirationTimestamp, 
            _triggerPrice, 
            _slippage, 
            _leverage, 
            _quoteAssetAmount
        );
    }
    function testExecuteOrder() public {}
    function testCancelOrder() public {}
}
