// SPDX-License-Identifier: GPL

pragma solidity ^0.8.0;

//import "../Libraries/Address.sol"; **Address is declared on NFT.sol"
import "https://github.com/Dexaran/CallistoNFT/blob/main/Libraries/Strings.sol";
import "https://github.com/Dexaran/CallistoNFT/blob/main/CallistoNFT.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721Receiver.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";

interface IClassifiedNFT is ICallistoNFT  {
    function setClassForTokenID(uint256 _tokenID, uint256 _tokenClass) external;
    function addNewTokenClass() external;
    function addTokenClassProperties(uint256 _propertiesCount) external;
    function modifyClassProperty(uint256 _classID, uint256 _propertyID, string memory _content) external;
    function getClassProperty(uint256 _classID, uint256 _propertyID) external view returns (string memory);
    function addClassProperty(uint256 _classID) external;
    function getClassProperties(uint256 _classID) external view returns (string[] memory);
    function getClassForTokenID(uint256 _tokenID) external view returns (uint256);
    function getClassPropertiesForTokenID(uint256 _tokenID) external view returns (string[] memory);
    function getClassPropertyForTokenID(uint256 _tokenID, uint256 _propertyID) external view returns (string memory);
    function mintWithClass(address _to, uint256 _tokenId, uint256 _classId)  external;
    function appendClassProperty(uint256 _classID, uint256 _propertyID, string memory _content) external;
}

/**
 * @title CallistoNFT Classified NFT
 * @dev This extension adds propeties to NFTs based on classes.
 */
abstract contract ClassifiedNFT is CallistoNFT, IClassifiedNFT {
    using Strings for string;

    mapping (uint256 => string[]) public class_properties;
    mapping (uint256 => uint256)  public token_classes;

    uint256 internal nextClassIndex = 0;

    modifier onlyExistingClasses(uint256 classId)
    {
        require(classId < nextClassIndex, "Queried class does not exist");
        _;
    }

    function setClassForTokenID(uint256 _tokenID, uint256 _tokenClass) public override /* onlyOwner */
    {
        token_classes[_tokenID] = _tokenClass;
    }

    function addNewTokenClass() public override /* onlyOwner */
    {
        class_properties[nextClassIndex].push("");
        nextClassIndex++;
    }

    function addTokenClassProperties(uint256 _propertiesCount) public override /* onlyOwner */
    {
        for (uint i = 0; i < _propertiesCount; i++)
        {
            class_properties[nextClassIndex].push("");
        }
    }

    function modifyClassProperty(uint256 _classID, uint256 _propertyID, string memory _content) public override /* onlyOwner */ onlyExistingClasses(_classID)
    {
        class_properties[_classID][_propertyID] = _content;
    }

    function getClassProperty(uint256 _classID, uint256 _propertyID) public override view onlyExistingClasses(_classID) returns (string memory)
    {
        return class_properties[_classID][_propertyID];
    }

    function addClassProperty(uint256 _classID) public override /* onlyOwner */ onlyExistingClasses(_classID)
    {
        class_properties[_classID].push("");
    }

    function getClassProperties(uint256 _classID) public override view onlyExistingClasses(_classID) returns (string[] memory)
    {
        return class_properties[_classID];
    }

    function getClassForTokenID(uint256 _tokenID) public override view onlyExistingClasses(token_classes[_tokenID]) returns (uint256)
    {
        return token_classes[_tokenID];
    }

    function getClassPropertiesForTokenID(uint256 _tokenID) public override view onlyExistingClasses(token_classes[_tokenID]) returns (string[] memory)
    {
        return class_properties[token_classes[_tokenID]];
    }

    function getClassPropertyForTokenID(uint256 _tokenID, uint256 _propertyID) public override view onlyExistingClasses(token_classes[_tokenID]) returns (string memory)
    {
        return class_properties[token_classes[_tokenID]][_propertyID];
    }
    
    function mintWithClass(address to, uint256 tokenId, uint256 classId)  public override /* onlyOwner */ onlyExistingClasses(classId)
    {
        _mint(to, tokenId);
        token_classes[tokenId] = classId;
    }

    function appendClassProperty(uint256 _classID, uint256 _propertyID, string memory _content) public override /* onlyOwner */ onlyExistingClasses(_classID)
    {
        class_properties[_classID][_propertyID] = class_properties[_classID][_propertyID].concat(_content);
    }
}

contract NFTWrapper is ClassifiedNFT {

    struct ERC721Source
    {
        address token_contract;
        uint256 token_id;
    }

    mapping (address => mapping (uint256 => uint256) ) public erc721_to_classID;  // Contract => ID => internalID
    mapping (uint256 => ERC721Source ) public classID_to_erc721;  // InternalID => Contract => ID

    uint256 internal last_minted_id;

    constructor(string memory name_, string memory symbol_, uint256 fee) CallistoNFT (name_, symbol_, fee) {
        
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

                transfer(from, _newId, data);
            }
            else
            {
                // Wrapper-token already exists.

                transfer(from, erc721_to_classID[msg.sender][tokenId], data);
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
