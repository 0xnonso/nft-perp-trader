// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

library Errors {
    error InvalidExpiration();
    error InvalidAccount();
    error CannotExecuteOrder();
    error NoOpenPositon();
    error InvalidManagerOrOperator();
}