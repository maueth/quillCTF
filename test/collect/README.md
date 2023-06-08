# Arbitrage

## Objective of CTF
You have 1 LP from the owner.

At the end of the test, you collect commission from your LP.

But it's too small for you. Increase the amount of commission, which you can get.

## Proof of Concept

The provided code aims to increase the amount of commission collected from a liquidity position (LP) in the NFTRent contract. Here's an explanation of each step in the solution:

1. Token Approvals:
- The `approve()` function is used to allow the router contract to spend 100 ether of `CatToken` and `DogToken` on behalf of the user. This approval is necessary for the subsequent token swap operation.

1. Token Swap:
- The `ExactInputSingleParams` struct is created, defining the parameters for the token swap operation.
- The `router.exactInputSingle()` function is called, swapping 100 ether worth of `CatToken` for as much `DogToken` as possible, based on the provided parameters.

1. Decreasing Liquidity:
- The `DecreaseLiquidityParams` struct is created, specifying the parameters for decreasing the liquidity in a position.
The `nonfungiblePositionManager.decreaseLiquidity()` function is called with the created parameters to decrease the liquidity in the LP.

1. Collecting Commission:
- The `CollectParams` struct is created, defining the parameters for collecting fees from the LP.
The `nonfungiblePositionManager.collect()` function is called with the created parameters to collect the fees owed to the position.
The collected commission amounts are returned and assigned to `collectAmount0` and `collectAmount1`.

1. Asserting the Commission Amount:
- The `assertGt()` function is used to assert that the collected `amount1` (commission) is greater than a specific threshold value (298214374191364123).

The overall solution aims to increase the commission collected from the LP by executing a token swap, decreasing the LP liquidity, and collecting the resulting fees. 


```
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
```