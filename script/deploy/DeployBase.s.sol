// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/FeeManager.sol";
import "../../src/NFTPerpOrder.sol";
import "../../test/utils/LibRLP.sol";

contract DeployBase is Script {
    FeeManager internal feeManager;
    NFTPerpOrder internal nftPerpOrder;
   
    address internal immutable clearingHouse;

    constructor(
        address _clearingHouse
    ){
        clearingHouse = _clearingHouse;
    }
        

    function run() public {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerKey);

        address nftPerpOrderAddress = LibRLP.computeAddress(deployerAddress, vm.getNonce(deployerAddress) + 2);

        vm.startBroadcast(deployerKey);

        feeManager = new FeeManager();
        nftPerpOrder = new NFTPerpOrder(
            clearingHouse,
            address(feeManager)
        );

        vm.stopBroadcast();
    }
}