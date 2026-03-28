// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";

contract NFT is ERC721 {
    // enum
    enum Mood {
        HAPPY,
        SAD
    }

    // state variables
    uint256 private s_tokenNo;
    mapping(uint256 => Mood) private s_TokenToMood;
    string private s_happyImage;
    string private s_sadImage;

    // constructor
    constructor(string memory happyImage, string memory sadImage) ERC721("Dynamic NFT", "DNFT") {
        s_tokenNo = 0;
        s_happyImage = happyImage;
        s_sadImage = sadImage;
    }

    // core functions
    function mintNFT() public {
        _mint(msg.sender, s_tokenNo);
        s_TokenToMood[s_tokenNo] = Mood.HAPPY;
        s_tokenNo++;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name":"',
                            name(),
                            '",',
                            '"description":"this is a dynamic on chain NFT",',
                            '"image":"',
                            getImageURI(tokenId),
                            '"}'
                        )
                    )
                )
            )
        );
    }

    // getter functions
    function getImageURI(uint256 _tokenId) public view returns (string memory) {
        string memory image;
        if (s_TokenToMood[_tokenId] == Mood.HAPPY) {
            image = s_happyImage;
        } else {
            image = s_sadImage;
        }
        return string(abi.encodePacked("data:image/svg+xml;base64,", image));
    }

    function flipMood(uint256 _tokenId) public {
        if (s_TokenToMood[_tokenId] == Mood.HAPPY) {
            s_TokenToMood[_tokenId] = Mood.SAD;
        } else {
            s_TokenToMood[_tokenId] = Mood.HAPPY;
        }
    }
}
