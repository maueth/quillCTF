// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "forge-std/Test.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {INonfungiblePositionManager} from "v3-periphery/interfaces/INonfungiblePositionManager.sol";
import {TickMath} from "v3-core/libraries/TickMath.sol";
import {IUniswapV3Factory} from "v3-core/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "v3-core/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "v3-periphery/interfaces/ISwapRouter.sol";

contract Token is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initialMint) ERC20(name, symbol) {
        _mint(msg.sender, initialMint);
    }
}

contract NFTRent is Test {
    Token DogToken;
    Token CatToken;
    uint256 tokenId1;
    uint256 defiMasterLP;
    uint128 defiMasterLiquidity;
    uint256 liquidity;
    address owner = makeAddr("owner");
    address defiMaster = makeAddr("defiMaster");
    address user = makeAddr("user");
    uint24 poolFee = 3000;
    IUniswapV3Pool pool;
    ISwapRouter router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    INonfungiblePositionManager nonfungiblePositionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    IUniswapV3Factory UNISWAP_FACTORY = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    function setUp() public {
        vm.createSelectFork("https://rpc.ankr.com/eth");

        vm.startPrank(owner);

        DogToken = new Token("DogToken", "DogToken", 1000000 ether);
        CatToken = new Token("CatToken", "CatToken", 1000000 ether);

        // gift from owner to user
        DogToken.transfer(user, 10000 ether);
        CatToken.transfer(user, 10000 ether);

        // owner lp
        // @note creates a new pool if it does not exist, then initializes if not initialized
        nonfungiblePositionManager.createAndInitializePoolIfNecessary(
            address(DogToken), address(CatToken), 3000, 1 << 96
        );

        // @note returns the pool address for a given pair of tokens and a fee, or address 0 if it does not exist
        pool = IUniswapV3Pool(UNISWAP_FACTORY.getPool(address(DogToken), address(CatToken), 3000));

        DogToken.approve(address(nonfungiblePositionManager), 10000 ether);
        CatToken.approve(address(nonfungiblePositionManager), 10000 ether);

        // @note populate the MintParams struct and assign it to a local variable params
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(DogToken),
            token1: address(CatToken),
            fee: poolFee,
            tickLower: -887220,
            tickUpper: 887220,
            amount0Desired: 1000 ether,
            amount1Desired: 1000 ether,
            amount0Min: 0,
            amount1Min: 0,
            recipient: owner,
            deadline: block.timestamp
        });

        /* 
            @note
            creates a new position wrapped in a NFT
            minting refers to the process of adding liquidity to a liquidity pool by depositing an equal value of two different tokens.
            When you mint liquidity, you create a position within the pool that represents your ownership of a specific range of  price 
            values.

            The liquidity you provided is now locked in the pool, and you receive a non-fungible token (NFT) representing your ownership 
            of the position. This NFT can be thought of as a certificate of the liquidity you contributed.
        */
        nonfungiblePositionManager.mint(params);

        uint256 amount;
        uint256 amount1;
        (defiMasterLP, defiMasterLiquidity, amount, amount1) = nonfungiblePositionManager.mint(params);

        // owner send to defiMaster LP 721 token
        nonfungiblePositionManager.safeTransferFrom(owner, defiMaster, defiMasterLP);
        vm.stopPrank();
    }

    function test_solution() public {
        vm.startPrank(user);

        CatToken.approve(address(router), 100 ether);
        DogToken.approve(address(router), 100 ether);

        // @note populate the ExactInputSingleParams struct and assign it to a local variable params
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(CatToken),
            tokenOut: address(DogToken),
            fee: 3000,
            recipient: user,
            deadline: block.timestamp,
            amountIn: 100 ether,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        // @note swaps amountIn of one token for as much as possible of another token
        router.exactInputSingle(params);

        vm.stopPrank();

        vm.startPrank(defiMaster);

        // @note populate the DecreaseLiquidityParams struct and assign it to a local variable paramsRemoveLiq
        INonfungiblePositionManager.DecreaseLiquidityParams memory paramsRemoveLiq = INonfungiblePositionManager
            .DecreaseLiquidityParams({
            tokenId: defiMasterLP,
            liquidity: defiMasterLiquidity,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp
        });

        uint256 amount0;
        uint256 amount1;
        // @note decreases the amount of liquidity in a position and accounts it to the position
        (amount0, amount1) = nonfungiblePositionManager.decreaseLiquidity(paramsRemoveLiq);

        // @note populate the CollectParams struct and assign it to a local variable collectParams
        INonfungiblePositionManager.CollectParams memory collectParams = INonfungiblePositionManager.CollectParams({
            tokenId: defiMasterLP,
            recipient: defiMaster,
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        });

        // @note collects up to a maximum amount of fees owed to a specific position to the recipient
        (uint256 collectAmount0, uint256 collectAmount1) = nonfungiblePositionManager.collect(collectParams);

        assertGt(collectAmount1, 298214374191364123);
        vm.stopPrank();
    }
}
