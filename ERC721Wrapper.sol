// SPDX-License-Identifier: GPL

pragma solidity ^0.8.1;

//import "../Libraries/Address.sol"; **Address is declared on NFT.sol"
import "https://github.com/Dexaran/CallistoNFT/blob/main/Libraries/Strings.sol";
import "https://github.com/Dexaran/CallistoNFT/blob/main/CallistoNFT.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721Receiver.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";

contract NFTWrapper is CallistoNFT {

    event Mint1();
    event Mint2();
    event Mint3();

    struct ERC721Source
    {
        address token_contract;
        uint256 token_id;
    }

    mapping (address => mapping (uint256 => uint256) ) public erc721_to_classID;  // Contract => ID => internalID
    mapping (uint256 => ERC721Source ) public classID_to_erc721;  // InternalID => Contract => ID

    uint256 internal last_minted_id;

    constructor(string memory name_, string memory symbol_, uint256 fee) CallistoNFT(name_, symbol_, fee) {
        emit Mint1();
    }

    function mintNext() internal returns (uint256 _mintedId)
    {
        last_minted_id++;
        _safeMint(address(this), last_minted_id);
        return last_minted_id;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4)
    {
        if(msg.sender == address(this))
        {
            // CallistoNFT received - unwrap and release ERC721 in return
            // Preserve CallistoNFT wrapper-token for future use in case of a repeated wrapping
            IERC721(classID_to_erc721[tokenId].token_contract).safeTransferFrom(address(this), from, classID_to_erc721[tokenId].token_id);

            emit Mint1();
        }
        else
        {
            // ERC721 received - freeze and mint CallistoNFT instead
            if(erc721_to_classID[msg.sender][tokenId] == 0)
            {
                // Wrapper-token for this ERC721 token contract does not exist.
                // Create a new entry and mint NFT then

                uint256 _newId = mintNext();

                // Once wrapper-NFT is created for ERC721-base NFT
                // it is preserved forever, at any point of time there is either ERC721-original
                // or wrapper-CallistoNFT in the contract.

                erc721_to_classID[msg.sender][tokenId] = _newId;
                classID_to_erc721[_newId].token_contract = msg.sender;
                classID_to_erc721[_newId].token_id = tokenId;

                // After token creation deliver the wrapper-token to the sender of the original

                CallistoNFT(address(this)).transfer(from, _newId, data);

                emit Mint2();
            }
            else
            {
                // Wrapper-token already exists.

                //transfer(from, erc721_to_classID[msg.sender][tokenId], data);

                emit Mint3();
            }
        }
        return IERC721Receiver.onERC721Received.selector;
    }

    /*
    function newClass(address _erc721Address) internal
    {
        erc721_to_classID[_erc721Address] = nextClassIndex;
        classID_to_erc721[nextClassIndex] = _erc721Address;
        addNewTokenClass();
    }
    */

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {}
}
