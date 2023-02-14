// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./DeployBase.s.sol";

contract DeployArb is DeployBase {
    address public constant _clearingHouse = 0x24D9D8767385805334ebd35243Dc809d0763b891;
    
    constructor() DeployBase(
        _clearingHouse
    ){}
}
