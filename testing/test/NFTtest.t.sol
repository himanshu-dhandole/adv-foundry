// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test, console } from "forge-std/Test.sol";
import { NFT } from "src/NFT.sol";

contract TestNFT is Test {
    NFT nft;
    address USER = makeAddr("user");

    string constant HAPPY_SVG =
        "PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxMDAgMTAwIj4KICA8Y2lyY2xlIGN4PSI1MCIgY3k9IjUwIiByPSI0OCIgZmlsbD0iI0ZGRDkzRCIgc3Ryb2tlPSIjMDAwIiBzdHJva2Utd2lkdGg9IjIiLz4KICAKICA8Y2lyY2xlIGN4PSIzNSIgY3k9IjQwIiByPSI1IiBmaWxsPSIjMDAwIi8+CiAgPGNpcmNsZSBjeD0iNjUiIGN5PSI0MCIgcj0iNSIgZmlsbD0iIzAwMCIvPgogIAogIDxwYXRoIGQ9Ik0zMCA2MCBRNTAgODAgNzAgNjAiIHN0cm9rZT0iIzAwMCIgc3Ryb2tlLXdpZHRoPSIzIiBmaWxsPSJub25lIiBzdHJva2UtbGluZWNhcD0icm91bmQiLz4KPC9zdmc+";
    string constant SAD_SVG =
        "PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxMDAgMTAwIj4KICA8Y2lyY2xlIGN4PSI1MCIgY3k9IjUwIiByPSI0OCIgZmlsbD0iIzg3Q0VFQiIgc3Ryb2tlPSIjMDAwIiBzdHJva2Utd2lkdGg9IjIiLz4KICAKICA8Y2lyY2xlIGN4PSIzNSIgY3k9IjQwIiByPSI1IiBmaWxsPSIjMDAwIi8+CiAgPGNpcmNsZSBjeD0iNjUiIGN5PSI0MCIgcj0iNSIgZmlsbD0iIzAwMCIvPgogIAogIDxwYXRoIGQ9Ik0zMCA3MCBRNTAgNTAgNzAgNzAiIHN0cm9rZT0iIzAwMCIgc3Ryb2tlLXdpZHRoPSIzIiBmaWxsPSJub25lIiBzdHJva2UtbGluZWNhcD0icm91bmQiLz4KPC9zdmc+";

    function setUp() public {
        nft = new NFT(HAPPY_SVG, SAD_SVG);
    }

    // --- Ai tests ---

    // 1. Test standard ERC721 initializations
    function testNameAndSymbol() public view {
        assertEq(nft.name(), "Dynamic NFT");
        assertEq(nft.symbol(), "DNFT");
    }

    // 2. Test successful minting and balance updates
    function testCanMintNFT() public {
        vm.prank(USER);
        nft.mintNFT();
        assertEq(nft.balanceOf(USER), 1);
        assertEq(nft.ownerOf(0), USER);
    }

    // 3. Test that token IDs increment correctly on multiple mints
    function testTokenCounterIncrements() public {
        vm.startPrank(USER);
        nft.mintNFT(); // ID: 0
        nft.mintNFT(); // ID: 1
        nft.mintNFT(); // ID: 2
        vm.stopPrank();

        assertEq(nft.balanceOf(USER), 3);
        assertEq(nft.ownerOf(0), USER);
        assertEq(nft.ownerOf(1), USER);
        assertEq(nft.ownerOf(2), USER);
    }

    // 4. Test that newly minted NFTs are HAPPY by default
    function testInitialMoodIsHappy() public {
        vm.prank(USER);
        nft.mintNFT();

        string memory expectedImageURI = string(abi.encodePacked("data:image/svg+xml;base64,", HAPPY_SVG));
        assertEq(nft.getImageURI(0), expectedImageURI);
    }

    // 5. Test that flipMood changes the image to SAD
    function testFlipMoodToSad() public {
        vm.startPrank(USER);
        nft.mintNFT();
        nft.flipMood(0);
        vm.stopPrank();

        string memory expectedImageURI = string(abi.encodePacked("data:image/svg+xml;base64,", SAD_SVG));
        assertEq(nft.getImageURI(0), expectedImageURI);
    }

    // 6. Test that flipMood twice toggles back to HAPPY
    function testFlipMoodToSadAndBackToHappy() public {
        vm.startPrank(USER);
        nft.mintNFT();
        nft.flipMood(0); // SAD
        nft.flipMood(0); // HAPPY
        vm.stopPrank();

        string memory expectedImageURI = string(abi.encodePacked("data:image/svg+xml;base64,", HAPPY_SVG));
        assertEq(nft.getImageURI(0), expectedImageURI);
    }

    // 7. Test tokenURI string format includes proper base64 json prefix
    function testTokenURIHasValidPrefix() public {
        vm.prank(USER);
        nft.mintNFT();

        string memory uri = nft.tokenURI(0);
        bytes memory uriBytes = bytes(uri);
        bytes memory expectedPrefix = bytes("data:application/json;base64,");

        assertTrue(uriBytes.length > expectedPrefix.length, "URI too short");
        for (uint256 i = 0; i < expectedPrefix.length; i++) {
            assertEq(uriBytes[i], expectedPrefix[i], "Invalid prefix in tokenURI");
        }
    }

    // 8. Test that tokenURI output changes completely when mood changes
    function testTokenURIChangesWhenMoodFlips() public {
        vm.startPrank(USER);
        nft.mintNFT();
        string memory uriHappy = nft.tokenURI(0);

        nft.flipMood(0);
        string memory uriSad = nft.tokenURI(0);
        vm.stopPrank();

        assertTrue(
            keccak256(abi.encodePacked(uriHappy)) != keccak256(abi.encodePacked(uriSad)), "Token URIs should differ"
        );
    }

    // 9. Test standard ERC721 transfer logic works properly
    function testTransferWorks() public {
        address receiver = makeAddr("receiver");

        vm.startPrank(USER);
        nft.mintNFT();
        nft.transferFrom(USER, receiver, 0);
        vm.stopPrank();

        assertEq(nft.balanceOf(USER), 0);
        assertEq(nft.balanceOf(receiver), 1);
        assertEq(nft.ownerOf(0), receiver);
    }

    // 10. Test that anyone can flip the mood (documenting current contract behavior)
    function testAnyoneCanFlipMood() public {
        vm.prank(USER);
        nft.mintNFT();

        // A random address calling flipMood on USER's NFT
        address randomAttacker = makeAddr("randomAttacker");

        vm.prank(randomAttacker);
        nft.flipMood(0); // Should succeed and change mode to SAD

        string memory expectedImageURI = string(abi.encodePacked("data:image/svg+xml;base64,", SAD_SVG));
        assertEq(nft.getImageURI(0), expectedImageURI);
    }
}
