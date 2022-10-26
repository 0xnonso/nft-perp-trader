// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "../../src/AccountFactory.sol";
import "../../src/FeeManager.sol";
import "../../src/NFTPerpOrder.sol";
import "../../src/NFTPerpOrderResolver.sol";
import "../../test/utils/LibRLP.sol";

contract DeployBase is Script {
    AccountFactory internal accountFactory;
    FeeManager internal feeManager;
    NFTPerpOrder internal nftPerpOrder;
    NFTPerpOrderResolver internal gelResolver;

    address ops;
    address taskTreasury;

    constructor(
        address _ops,
        address _taskTreasury
    ){
        ops = _ops;
        taskTreasury = _taskTreasury; 
    }

    function setUp() public {}
        

    function run() public {
        vm.startBroadcast();

        address nftPerpOrderAddress = LibRLP.computeAddress(tx.origin, vm.getNonce(tx.origin) + 3);

        accountFactory = new AccountFactory(
            nftPerpOrderAddress
        );
        gelResolver = new NFTPerpOrderResolver(
            nftPerpOrderAddress, 
            payable(ops)
        );
        feeManager = new FeeManager(
            address(gelResolver), 
            payable(taskTreasury)
        );
        nftPerpOrder = new NFTPerpOrder(
            address(accountFactory),
            address(feeManager)
        );

        vm.stopBroadcast();
    }
}