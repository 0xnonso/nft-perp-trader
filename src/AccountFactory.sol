// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import {ClonesWithImmutableArgs} from "clones-with-immutable-args/ClonesWithImmutableArgs.sol";
import "./interfaces/INFTPerpOrder.sol";
import "./interfaces/IAccountFactory.sol";

contract AccountFactory is IAccountFactory {
    using ClonesWithImmutableArgs for address;

    /// @dev Account implementation contract
    address internal immutable implementation;
    address internal immutable _NFTPerpOrder_;
    address public immutable clearingHouse;
    //mapping (Account -> bool)
    mapping(address => bool) public validAccount;

     constructor(address _nftPerpOrder, address _clearingHouse){
        implementation = address(new Account());
        _NFTPerpOrder_ = _nftPerpOrder;
        clearingHouse = _clearingHouse;
     }

    ///@notice Deploys a clone account contract
    ///        - Account Manager is the NFT-perp-order contract which can execute order on behalf of the account's operator/owner
    ///@param operator Account controller/owner
    function createAccount(
        address operator
    ) external override returns(Account account){
        bytes memory data = abi.encodePacked(_NFTPerpOrder_, operator, clearingHouse);
        account = Account(implementation.clone(data));
        validAccount[address(account)] = true;

        emit NFTPerpAccountCreated(address(account));
    }

}