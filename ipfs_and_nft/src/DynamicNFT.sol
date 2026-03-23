// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

/**
 * @title Evolving NFT
 * @author HImanshu Dhandole
 * @notice this uses base64 for encoding
 */
contract DynamicNFT is ERC721 {
    // errors
    error DynamicNFT__NotTheOwnerOfNFT();

    // state variables
    string private s_simpleSword;
    string private s_windSword;
    string private s_godSword;
    uint256 private s_tokenNumber;

    // enum
    enum Sword {
        SIMPLE_SWORD,
        WIND_SWORD,
        GOD_SWORD
    }

    mapping(uint256 => Sword) public s_TokenIdToSword;

    constructor(
        string memory simpleSwordURI,
        string memory windSwordURI,
        string memory godSwordURI
    ) ERC721("Evolving Swords NFT", "SNFT") {
        s_simpleSword = simpleSwordURI;
        s_windSword = windSwordURI;
        s_godSword = godSwordURI;
        s_tokenNumber = 0;
    }

    function mintNFT() public {
        _safeMint(msg.sender, s_tokenNumber);
        s_TokenIdToSword[s_tokenNumber] = Sword.SIMPLE_SWORD;
        s_tokenNumber++;
    }

    function _baseURI() internal view override returns (string memory) {
        return "data:application/json;base64,";
    }

    function upgradeSword(uint256 _tokenNumber) public {
        address owner = ownerOf(_tokenNumber);
        _checkAuthorized(msg.sender, owner, _tokenNumber);
        if (s_TokenIdToSword[_tokenNumber] == Sword.SIMPLE_SWORD) {
            s_TokenIdToSword[_tokenNumber] = Sword.WIND_SWORD;
        } else if (s_TokenIdToSword[_tokenNumber] == Sword.WIND_SWORD) {
            s_TokenIdToSword[_tokenNumber] = Sword.GOD_SWORD;
        } else {
            revert("Already at max level !");
        }
    }

    function tokenURI(
        uint256 _tokenNumber
    ) public view override returns (string memory) {
        string memory imageURI;
        if (s_TokenIdToSword[_tokenNumber] == Sword.SIMPLE_SWORD) {
            imageURI = s_simpleSword;
        } else if (s_TokenIdToSword[_tokenNumber] == Sword.WIND_SWORD) {
            imageURI = s_windSword;
        } else {
            imageURI = s_godSword;
        }

        string memory tokenMetadata = string(
            abi.encodePacked(
                _baseURI(),
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            "{",
                            '"name":"',
                            name(),
                            '",',
                            '"description":"this is a dynamic sword nft which reacts to ur Sepolia Eth balance",',
                            '"attributes":[{"trait_type":"level","value":1}],',
                            '"image":"',
                            imageURI,
                            '"',
                            "}"
                        )
                    )
                )
            )
        );
        return tokenMetadata;
    }
}
