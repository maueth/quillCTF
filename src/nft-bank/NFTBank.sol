// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {ERC721Holder} from "openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "forge-std/Test.sol";

contract NFTBank is ReentrancyGuard, ERC721Holder {
    struct rentData {
        address collection;
        uint256 id;
        uint256 startDate;
    }

    struct nftData {
        address owner;
        uint256 rentFeePerDay;
        uint256 startRentFee;
    }

    mapping(address => mapping(uint256 => nftData)) public nfts;
    mapping(address => mapping(uint256 => uint256)) public collectedFee;
    rentData[] public rentNFTs;

    error WrongETHValue();
    error YouAreNotOwner();

    function addNFT(address collection, uint256 id, uint256 rentFeePerDay, uint256 startRentFee) external {
        nfts[collection][id] = nftData({owner: msg.sender, rentFeePerDay: rentFeePerDay, startRentFee: startRentFee});
        IERC721(collection).safeTransferFrom(msg.sender, address(this), id);
        console.log("nft added id ", id);
    }

    function getBackNft(address collection, uint256 id, address payable transferFeeTo) external {
        console.log("owner ", nfts[collection][id].owner);
        if (msg.sender != nfts[collection][id].owner) revert YouAreNotOwner();
        IERC721(collection).safeTransferFrom(address(this), msg.sender, id);
        transferFeeTo.transfer(collectedFee[collection][id]);
    }

    function rent(address collection, uint256 id) external payable {
        console.log("\n rent id ", id);
        console.log("msg sender ", msg.sender);

        IERC721(collection).safeTransferFrom(address(this), msg.sender, id); 
        console.log("safeTransferFrom complete ", id);

        /**
         * @audit
         * transfer the 10 tokens to attacker
         *
         * in the last loop only the last nft will be pushed to renNFTs list
         */
        if (msg.value != nfts[collection][id].startRentFee) {
            revert WrongETHValue();
        }
        console.log("msg.value ", msg.value);

        rentNFTs.push(rentData({collection: collection, id: id, startDate: block.timestamp}));
        console.log("nft rented timestamp", block.timestamp);
    }

    function refund(address collection, uint256 id) external payable nonReentrant {
        console.log("\n refund");
        console.log("owner ", nfts[collection][id].owner);
        console.log("owner ", IERC721(collection).ownerOf(1));
        console.log("collectedFee ", collectedFee[collection][id]);
        IERC721(collection).safeTransferFrom(msg.sender, address(this), id);
        console.log("safeTransferFrom");

        rentData memory rentedNft = rentData({collection: address(0), id: 0, startDate: 0});

        for (uint256 i; i < rentNFTs.length; i++) {
            if (rentNFTs[i].collection == collection && rentNFTs[i].id == id) {
                rentedNft = rentNFTs[i];
            }
        }
        console.log("rentedNft id ", rentedNft.id);

        uint256 daysInRent =
            (block.timestamp - rentedNft.startDate) / 86400 > 1 ? (block.timestamp - rentedNft.startDate) / 86400 : 1;
        console.log("daysInRent ", daysInRent);

        uint256 amount = daysInRent * nfts[collection][id].rentFeePerDay;
        console.log("amount ", amount);

        if (msg.value != amount) revert WrongETHValue();
        uint256 index;
        for (uint256 i; i < rentNFTs.length; i++) {
            if (rentNFTs[i].collection == collection && rentNFTs[i].id == id) {
                index = i;
            }
        }
        collectedFee[collection][id] += amount;
        console.log("collectedFee ", collectedFee[collection][id]);

        console.log("startRentFee ", nfts[rentNFTs[index].collection][rentNFTs[index].id].startRentFee);
        payable(msg.sender).transfer(nfts[rentNFTs[index].collection][rentNFTs[index].id].startRentFee);

        rentNFTs[index] = rentNFTs[rentNFTs.length - 1];
        rentNFTs.pop();

        console.log("finish");
    }
}
