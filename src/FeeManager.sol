// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract FeeManager is Ownable() {

    IERC20 public constant ETH = ;

    function withraw(IERC20 token, address reciever, uint256 amount) public payable onlyOwner(){
        require(amount > 0, "zero_amount");
        if(token = ETH){
            (bool sent,) = reciever.call{value: amount}("");
            require(sent, "transfer_failed");
        } else { 
            token.transfer(reciever, amount); 
        }
    }

    receive() external payable {}
}