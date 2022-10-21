// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;
import "../Account.sol";
interface IAccountFactory {
    event NFTPerpAccountCreated(address _account);

    function createAccount(
        address manager, 
        address operator
    ) external returns(Account);
}