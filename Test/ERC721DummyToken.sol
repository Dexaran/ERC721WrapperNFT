// SPDX-License-Identifier: GPL

pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721Receiver.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";

contract ERC721TestToken is ERC721("Test NFT token", "TTK1") {
    function give(uint256 tokenId) public
    {
        _safeMint(msg.sender, tokenId);
    }
}
