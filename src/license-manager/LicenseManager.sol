// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

/**
 * @title LicenseManager CTF
 * @dev We are looking at a Smart Contract called LicenseManager for managing licenses that cost 1 ether. As attackers, we only have 0.01 ether instead, and our first goal is to get the license anyway. Also, find at least two ways to collect the ethers in the contract before the owner notices.
 */
contract LicenseManager {
    address private owner;
    address[] private licensed;
    mapping(address => bool) private licenseOwners;

    constructor() {
        owner = msg.sender;
    }

    function buyLicense() public payable {
        require(msg.value == 1 ether || msg.sender == owner, "Send 1 ether to buy a license. Owner can ask for free");
        licensed.push(msg.sender);
        licenseOwners[msg.sender] = true;
    }

    function checkLicense() public view returns (bool) {
        return licenseOwners[msg.sender];
    }

    function winLicense() public payable returns (bool) {
        // @audit-info checks msg.value
        require(msg.value >= 0.01 ether && msg.value <= 0.5 ether, "Send between 0.01 and 0.5 ether to try your luck");

        // @audit-info defines threshold
        uint256 maxThreshold = uint256((msg.value / 1e16));
        console.log("maxThreshold ", maxThreshold);

        // @audit-info defines algorithm
        // @audit the only var I can try to manipulate is block.number
        uint256 algorithm = uint256(
            keccak256(abi.encodePacked(uint256(msg.value), msg.sender, uint256(1337), blockhash(block.number - 1)))
        );
        console.log("algorithm ", algorithm);

        // @audit-info gets a number
        uint256 pickedNumber = algorithm % 100;
        console.log("pickedNumber ", pickedNumber);

        // @audit-info checks if pickedNumber is less than maxThreshold
        console.log("pickedNumber < maxThreshold ", pickedNumber < maxThreshold);
        if (pickedNumber < maxThreshold) {
            licenseOwners[msg.sender] = true;
        }

        return licenseOwners[msg.sender];
    }

    function refundLicense() public {
        // @audit-info check if user is licensed
        require(licenseOwners[msg.sender] == true, "You are not a licensed user");

        // @audit-info goes through all licensed addrs
        for (uint256 i = 0; i < licensed.length; i++) {
            // @audit-info gets msg.sender license
            if (licensed[i] == msg.sender) {
                // @audit-info removes licensed
                licensed[i] = licensed[licensed.length - 1];
                licensed.pop();
                break;
            }
        }

        // @audit-info sends 1 ether to msg.sender
        (bool success,) = msg.sender.call{value: 1 ether}("");
        require(success, "Transfer failed.");

        // @audit-info flag msg.sender as false
        // @audit does not follow CEI pattern
        licenseOwners[msg.sender] = false;
    }

    // @audit-info withdraws funds
    function collect() public {
        // @audit not possible to exploit owner storage var
        require(msg.sender == owner, "Only the owner can collect.");
        (bool success,) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }
}
