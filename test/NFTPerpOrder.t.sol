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
    string ARB_RPC_URL = vm.envString("ARB_RPC_URL");

    function setUp() public {

        vm.createSelectFork(ARB_RPC_URL);
        address _ops = 0xB3f5503f93d5Ef84b06993a1975B9D21B962892F;
        address _taskTreasury = 0xB2f34fd4C16e656163dADFeEaE4Ae0c1F13b140A;

        utils = new Utilities();

        address nftPerpOrderAddress = utils.predictContractAddress(address(this), 3);

        accountFactory = new AccountFactory(
            nftPerpOrderAddress
        );
        gelResolver = new NFTPerpOrderResolver(
            nftPerpOrderAddress, 
            _ops
        );
        feeManager = new FeeManager(
            address(gelResolver), 
            _taskTreasury
        );
        nftPerpOrder = new NFTPerpOrder(
            address(accountFactory),
            address(feeManager)
        );
        require(address(nftPerpOrder) == nftPerpOrderAddress, "fvdfd");
    }

    function testCreateOrder() public {
        IAmm _amm = IAmm(0xb50BedcA449f7F9980c3606e4Fe1FB8F48C6A228);
        Structs.OrderType _orderType = Structs.OrderType.BUY_SLO;
        address _account = address(0);
        uint64 _expirationTimestamp = uint64(block.timestamp + 25 minutes);
        uint256 _triggerPrice= 8082144660937355288;
        Decimal.decimal memory _slippage = Decimal.decimal(0);
        Decimal.decimal memory _leverage = Decimal.decimal(1e18);
        Decimal.decimal memory _quoteAssetAmount = Decimal.decimal(2e18);

        uint256 _taskAmount = 1e18;
        deal(address(feeManager), _taskAmount);
        feeManager.fundGelatoTasksETH(_taskAmount);
        gelResolver.startTask();

        // address user = 0xCAB63fE1C73379e81c5D078169d1165Dc1009Fae;
        // vm.prank(user);
        deal(address(_amm.quoteAsset()), address(this), 3e18);
        _amm.quoteAsset().approve(address(nftPerpOrder), type(uint).max);
        console.log(_amm.quoteAsset().balanceOf(address(this)));
        console.log(_quoteAssetAmount.toUint());
        (Decimal.decimal memory toll, Decimal.decimal memory spread) = _amm.calcFee(
                _quoteAssetAmount,
                IClearingHouse.Side.BUY
            );
        console.log(toll.addD(spread).toUint());

        // bytes32 hashOrder = nftPerpOrder.createOrder(
        //     _amm, 
        //     _orderType, 
        //     _account, 
        //     _expirationTimestamp, 
        //     _triggerPrice, 
        //     _slippage, 
        //     _leverage, 
        //     _quoteAssetAmount
        // );
        // nftPerpOrder.executeOrder(hashOrder);

        Account _account_ =  accountFactory.createAccount(address(this));
        require(_account_.getOperator() == address(this), "dedada");
        _amm.quoteAsset().transfer(
                address(_account_),
                _quoteAssetAmount.toUint()
            );

         Decimal.decimal memory quoteAssetAmount = (_quoteAssetAmount.mulD(_quoteAssetAmount))
                .divD(_quoteAssetAmount.addD(toll.addD(spread)));
        _account_.openPosition(_amm, IClearingHouse.Side.BUY, quoteAssetAmount, _leverage, _slippage);
        console.log(_amm.quoteAsset().balanceOf(address(_account_)));
        bytes32 hashOrder = nftPerpOrder.createOrder(
            _amm, 
            _orderType, 
            address(_account_), 
            _expirationTimestamp, 
            _triggerPrice, 
            _slippage, 
            _leverage, 
            _quoteAssetAmount
        );
        gelResolver.checker();
        //nftPerpOrder.executeOrder(hashOrder);
    }
    function testExecuteOrder() public {}
    function testCancelOrder() public {}
}
