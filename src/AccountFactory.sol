// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import {ClonesWithImmutableArgs} from "clones-with-immutable-args/ClonesWithImmutableArgs.sol";
import "./interfaces/INFTPerpOrder.sol";
import "./interfaces/IAccountFactory.sol";

contract AccountFactory is IAccountFactory {
    using ClonesWithImmutableArgs for address;

    /// @dev Account implementation contract
    address internal immutable implementation;
    mapping(address => bool) public validAccount;

     constructor(){
        implementation = address(new Account());
     }

    function createAccount(
        address manager, 
        address operator
    ) external returns(Account account){
        bytes memory data = abi.encodePacked(manager, operator);
        account = Account(implementation.clone(data));
        validAccount[address(account)] = true;

        emit NFTPerpAccountCreated(address(account));
    }

}