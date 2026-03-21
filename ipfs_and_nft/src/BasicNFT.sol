// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

/**
 * @title a Sample nft using IPFS for learning purpose
 * @author Himanshu Dhandole
 * @notice this uses IPFS to store the NFT data
 */
contract BasicNFT is ERC721 {
    // state variables and mappings
    uint256 private s_tokenNumber;
    mapping(uint256 => string) s_TokenNumberToURI;

    constructor() ERC721("Non Fungible Friends", "NFF") {
        s_tokenNumber = 0;
    }

    function mintNFT(string memory _tokenURI) public {
        s_TokenNumberToURI[s_tokenNumber] = _tokenURI;
        _safeMint(msg.sender, s_tokenNumber);
        s_tokenNumber++;
    }

    function tokenURI(
        uint256 _tokenNumber
    ) public view override returns (string memory) {
        return s_TokenNumberToURI[_tokenNumber];
    }

    // view / getter functions
    function getTokenToURI(
        uint256 _tokenNumber
    ) external view returns (string memory) {
        return s_TokenNumberToURI[_tokenNumber];
    }

    function getCurrentTokenNumber() external view returns (uint256) {
        return s_tokenNumber;
    }
}
