## Arbitragebot

You can find more details at the following link: [https://docs.google.com/presentation/d/1SycsVWWGY7SzRRA-9bu-Q29a_cBJsw6Y6jNfnob3z9k/edit?usp=sharing](https://docs.google.com/presentation/d/1SycsVWWGY7SzRRA-9bu-Q29a_cBJsw6Y6jNfnob3z9k/edit?usp=sharing)

```
# step0: local forked mainnet
$ anvil --fork-url https://mainnet.chainnodes.org/<your_api_key> --fork-block-number 20487429 --fork-chain-id 1 --chain-id 1
```

```
# step1: deploy contract
$ forge create --rpc-url http://0.0.0.0:8545 --private-key <private_key_1> src/ArbitrageBot.sol:ArbitrageBot

# step2: deposit weth into the contract
$ cast send 0x33f4f8bf90d8AA3d19fF812B50e79c15Df0d0b03 "depositWETH()" --rpc-url http://0.0.0.0:8545 --private-key <private_key_1> --value "1ether"
$ cast call 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 "balanceOf(address)(uint256)" 0x33f4f8bf90d8AA3d19fF812B50e79c15Df0d0b03 --rpc-url http://0.0.0.0:8545

# step3: swap weth into usdc with uniswapv3
# 1weth = 2667.740322 usdc (uniswap)
$ cast send 0x33f4f8bf90d8AA3d19fF812B50e79c15Df0d0b03 "sellWETHOnUniswap(uint256)" 1000000000000000000 --rpc-url http://0.0.0.0:8545 --private-key <private_key_1>
$ cast call 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 "balanceOf(address)(uint256)" 0x33f4f8bf90d8AA3d19fF812B50e79c15Df0d0b03 --rpc-url http://0.0.0.0:8545

# step4: Player B deposits and sells 1000 WETH to cause the WETH price to fluctuate on Uniswap V3
# 1weth = 2416.60653344 usdc (uniswap) [0.4138034 weth = 1000 usdc]
# 1weth = 2681.20601672 usdc (curve) [0.372966491110019544 weth = 1000 usdc]
$ forge create --rpc-url http://0.0.0.0:8545 --private-key <private_key_2> src/ArbitrageBot.sol:ArbitrageBot
$ cast send 0x8896Dce0E60a706244553ADA1aAc5CDCc40a0428 "depositWETH()" --rpc-url http://0.0.0.0:8545 --private-key <private_key_2> --value "1000ether"
$ cast send 0x8896Dce0E60a706244553ADA1aAc5CDCc40a0428 "sellWETHOnUniswap(uint256)" 1000000000000000000000 --rpc-url http://0.0.0.0:8545 --private-key <private_key_2>
$ cast send 0x8896Dce0E60a706244553ADA1aAc5CDCc40a0428 "getAmountOutUniswapV3(uint256)" 1000000000 --rpc-url http://0.0.0.0:8545 --private-key <private_key_2>
$ cast send 0x8896Dce0E60a706244553ADA1aAc5CDCc40a0428 "getAmountOutCurve(uint256)" 1000000000 --rpc-url http://0.0.0.0:8545 --private-key <private_key_2>

# step5: executeArbitrage
# amountInUSDC = 2416606534
# estimateProfit = 265
# actual profit = 250.085552
$ cast send 0x33f4f8bf90d8AA3d19fF812B50e79c15Df0d0b03 "executeArbitrage(uint256)" 2416606534 --rpc-url http://0.0.0.0:8545 --private-key <private_key_1>
$ cast call 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 "balanceOf(address)(uint256)" 0x33f4f8bf90d8AA3d19fF812B50e79c15Df0d0b03 --rpc-url http://0.0.0.0:8545

# step6: withdraw usdc from the contract
cast send 0x33f4f8bf90d8AA3d19fF812B50e79c15Df0d0b03 "sendTokenBack(address,uint256)" "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" 2917825874 --rpc-url http://0.0.0.0:8545 --private-key <private_key_1>
```
