// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/FeeManager.sol";
import "../../src/NFTPerpOrder.sol";
import "../../src/NFTPerpOrderResolver.sol";
import "../../test/utils/LibRLP.sol";

contract DeployBase is Script {
    FeeManager internal feeManager;
    NFTPerpOrder internal nftPerpOrder;
    NFTPerpOrderResolver internal gelResolver;

    address internal immutable ops;
    address internal immutable taskTreasury;
    address internal immutable clearingHouse;

    constructor(
        address _ops,
        address _taskTreasury,
        address _clearingHouse
    ){
        ops = _ops;
        taskTreasury = _taskTreasury; 
        clearingHouse = _clearingHouse;
    }
        

    function run() public {
        vm.startBroadcast();

        address nftPerpOrderAddress = LibRLP.computeAddress(tx.origin, vm.getNonce(tx.origin) + 2);

        gelResolver = new NFTPerpOrderResolver(
            nftPerpOrderAddress, 
            ops
        );
        feeManager = new FeeManager(
            address(gelResolver), 
            taskTreasury
        );
        nftPerpOrder = new NFTPerpOrder(
            address(feeManager)
        );

        vm.stopBroadcast();
    }
}