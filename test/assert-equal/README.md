# assertEqual

The objective is to create a smart contract that checks whether two unsigned integers are equal. If they are equal, the contract should return 1; otherwise, it should return 0. However, there are several opcodes that cannot be used directly, such as EQ, which would normally compare the integers directly.

In the test file, when the smart contract is called, it sends a value of 4 wei. To work around the banned 0x04 byte, which is needed for the 4-byte function signature, the CALLVALUE opcode is used to push 4 onto the stack.

To solve this problem without using the forbidden opcodes, the approach involves writing data to a storage slot and then checking if the slot has been written to determine if the integers are equal. For example, if the contract checks whether 1 is equal to 2, it will write some data to storage slot 1. Subsequently, it checks if storage slot 2 has been written to determine if the integers are equal.

In summary, the bytecode employs alternative methods to work around the banned opcodes, such as utilizing specific stack values, manipulating storage slots, and using loop structures to achieve the desired functionality without directly using the forbidden opcodes.

```
    PUSH21 0x4634355560243554151560005260206000f3000000
    PUSH1 0x00
    MSTORE
    PUSH1 0x15
    PUSH1 0x0b
    RETURN

    744634355560243554151560005260206000f30000006000526015600bf3
```


```
    contract EQ is Test {
        address isNumbersEQContract;
        bytes1[] badOpcodes;

        function setUp() public {
            badOpcodes.push(hex"01");
            badOpcodes.push(hex"02"); // MUL
            badOpcodes.push(hex"03"); // SUB
            badOpcodes.push(hex"04"); // DIV
            badOpcodes.push(hex"05"); // SDIV
            badOpcodes.push(hex"06"); // MOD
            badOpcodes.push(hex"07"); // SMOD
            badOpcodes.push(hex"08"); // ADDMOD
            badOpcodes.push(hex"09"); // MULLMOD
            badOpcodes.push(hex"18"); // XOR
            badOpcodes.push(hex"10"); // LT
            badOpcodes.push(hex"11"); // GT
            badOpcodes.push(hex"12"); // SLT
            badOpcodes.push(hex"13"); // SGT
            badOpcodes.push(hex"14"); // EQ
            badOpcodes.push(hex"f0"); // create
            badOpcodes.push(hex"f5"); // create2
            badOpcodes.push(hex"19"); // NOT
            badOpcodes.push(hex"1b"); // SHL
            badOpcodes.push(hex"1c"); // SHR
            badOpcodes.push(hex"1d"); // SAR
            vm.createSelectFork(
                "https://rpc.ankr.com/eth"
            );
            address isNumbersEQContractTemp;
            // solution - your bytecode
            bytes
                memory bytecode = hex"744634355560243554151560005260206000f30000006000526015600bf3";
            //
            require(bytecode.length < 40, "try harder!");
            for (uint i; i < bytecode.length; i++) {
                for (uint a; a < badOpcodes.length; a++) {
                    if (bytecode[i] == badOpcodes[a]) revert();
                }
            }

            assembly {
                isNumbersEQContractTemp := create(
                    0,
                    add(bytecode, 0x20),
                    mload(bytecode)
                )
                if iszero(extcodesize(isNumbersEQContractTemp)) {
                    revert(0, 0)
                }
            }
            isNumbersEQContract = isNumbersEQContractTemp;
        }

        // fuzzing test
        function test_isNumbersEq(uint8 a, uint8 b) public {
            (bool success, bytes memory data) = isNumbersEQContract.call{value: 4}(
                abi.encodeWithSignature("isEq(uint256, uint256)", a, b)
            );
            require(success, "!success");
            uint result = abi.decode(data, (uint));
            a == b ? assert(result == 1) : assert(result != 1);

            // additional tests
            // 1 - equal numbers
            (, data) = isNumbersEQContract.call{value: 4}(
                abi.encodeWithSignature("isEq(uint256, uint256)", 57204, 57204)
            );
            require(abi.decode(data, (uint)) == 1, "1 test fail");
            // 2 - different numbers
            (, data) = isNumbersEQContract.call{value: 4}(
                abi.encodeWithSignature("isEq(uint256, uint256)", 0, 3568)
            );
            require(abi.decode(data, (uint)) != 1, "2 test fail");
        }
    }
```