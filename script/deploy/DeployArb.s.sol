// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./DeployBase.s.sol";

contract DeployArb is DeployBase {
    address public constant _ops = 0xB3f5503f93d5Ef84b06993a1975B9D21B962892F;
    address public constant _taskTreasury = 0xB2f34fd4C16e656163dADFeEaE4Ae0c1F13b140A;
    address public constant _clearingHouse = 0x24D9D8767385805334ebd35243Dc809d0763b891;
    
    constructor()DeployBase(
        _ops,
        _taskTreasury,
        _clearingHouse
    ){}
}
