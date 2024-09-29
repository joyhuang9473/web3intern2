// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import '@uniswap/v3-core/contracts/libraries/FullMath.sol';

contract ArbitrageBot {
    ISwapRouter private constant uniswapV3Router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IUniswapV3Factory private constant uniswapV3Factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    ICryptoPool private constant curvePool = ICryptoPool(0x7F86Bf177Dd4F3494b841a37e810A34dD56c829B);

    IWETH private constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 private constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    // uint usdc_decimal = 6;
    // uint weth_decimal = 18;

    address payable private administrator;

    receive() external payable {}

    modifier onlyAdmin() {
        require(msg.sender == administrator || msg.sender == address(this), "admin only");
        _;
    }

    constructor() {
        administrator = payable(msg.sender);
    }

    function depositWETH() external payable {
        WETH.deposit{value : msg.value}();
    }

    function sendTokenBack(address token, uint256 amount) external onlyAdmin {
        IERC20(token).transfer(administrator, amount);
    }

    function getAmountOutUniswapV3(uint256 amountIn) external view returns (uint256 amountOut) {
        // refer: https://blog.uniswap.org/uniswap-v3-math-primer
        // Get the pool address for the pair
        address poolAddress = uniswapV3Factory.getPool(address(USDC), address(WETH), 3000); // 0.3% fee tier
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();
        uint256 price = uint256(sqrtPriceX96) * uint256(sqrtPriceX96) / (1 << 192);
        amountOut = amountIn * price; // 373714029000000000
    }

    function getAmountOutCurve(uint256 amountIn) external view returns (uint256 amountOut) {
        amountOut = curvePool.get_dy(0, 2, amountIn);
    }

    function sellWETHOnUniswap(uint256 amountIn) external onlyAdmin returns (uint256 amountOut) {
        require(WETH.balanceOf(address(this)) >= amountIn, "WETH balanceOf not enough");
        amountOut = swapExactInputSingleHop(address(WETH), address(USDC), 3000, amountIn);
    }

    function buyWETHOnUniswap(uint256 amountIn) external onlyAdmin returns (uint256 amountOut) {
        require(USDC.balanceOf(address(this)) >= amountIn, "USDC balanceOf not enough");
        amountOut = swapExactInputSingleHop(address(USDC), address(WETH), 3000, amountIn);
    }

    function swapExactInputSingleHop(
        address tokenIn,
        address tokenOut,
        uint24 poolFee,
        uint256 amountIn
    )
        internal
        returns (uint256 amountOut)
    {
        IERC20(tokenIn).approve(address(uniswapV3Router), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: poolFee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        amountOut = uniswapV3Router.exactInputSingle(params);
    }

    function sellWETHOnCurve(uint256 amountIn) external onlyAdmin returns (uint256 amountOut) {
        require(WETH.balanceOf(address(this)) >= amountIn, "WETH balanceOf not enough");
        IERC20(address(WETH)).approve(address(curvePool), amountIn);
        amountOut = curvePool.exchange(2, 0, amountIn, 1);
    }

    function buyWETHOnCurve(uint256 amountIn) external onlyAdmin returns (uint256 amountOut) {
        require(USDC.balanceOf(address(this)) >= amountIn, "USDC balanceOf not enough");
        IERC20(address(USDC)).approve(address(curvePool), amountIn);
        amountOut = curvePool.exchange(0, 2, amountIn, 1);
    }

    function executeArbitrage(uint256 amountInUSDC) external onlyAdmin returns (uint256 profit) {
        require(USDC.balanceOf(address(this)) >= amountInUSDC, "USDC balanceOf not enough");
        uint256 amountOutWETH;
        uint256 amountOutUSDC;

        // // Step 1: Get price from Uniswap V3
        uint256 ethAmountFromUniswap = this.getAmountOutUniswapV3(amountInUSDC);

        // // Step 2: Get price from Curve
        uint256 ethAmountFromCurve = this.getAmountOutCurve(amountInUSDC);

        // // Step 3: Compare and perform arbitrage
        if (ethAmountFromUniswap > ethAmountFromCurve) {
            // Buy WETH on Uniswap and sell on Curve
            amountOutWETH = this.buyWETHOnUniswap(amountInUSDC);
            amountOutUSDC = this.sellWETHOnCurve(amountOutWETH);
        } else {
            // Buy WETH on Curve and sell on Uniswap
            amountOutWETH = this.buyWETHOnCurve(amountInUSDC);
            amountOutUSDC = this.sellWETHOnUniswap(amountOutWETH);
        }

        require(amountOutUSDC > amountInUSDC, "Arbitrage profit <= 0");
        profit = amountOutUSDC - amountInUSDC;
    }

    function getCoinsFromCurvePool(uint256 index) external view returns (address) {
        // 0: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
        // 1: 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599
        // 2: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
        return curvePool.coins(index);
    }

}

/// @title Uniswap V3 Swap Router interface
/// @notice Interface for the Uniswap V3 Swap Router
interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps amountIn of one token for as much as possible of another token
    /// @param params The parameters necessary for the swap, encoded as ExactInputSingleParams in calldata
    /// @return amountOut The amount of the received token
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    /// @notice Swaps amountIn of one token for as much as possible of another along the specified path
    /// @param params The parameters necessary for the multi-hop swap, encoded as ExactInputParams in calldata
    /// @return amountOut The amount of the received token
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);
}

/// @title ERC20 interface
/// @notice Interface for the EIP20 standard token.
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

/// @title WETH interface
/// @notice Interface for the WETH token.
interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

// refer: https://etherscan.io/address/0x16c6521dff6bab339122a0fe25a9116693265353#code
// interface CryptoPool:
//     def get_dy(i: uint256, j: uint256, amount: uint256) -> uint256: view
//     def exchange(i: uint256, j: uint256, dx: uint256, min_dy: uint256): payable
//     def get_dy_underlying(i: uint256, j: uint256, amount: uint256) -> uint256: view
//     def exchange_underlying(i: uint256, j: uint256, dx: uint256, min_dy: uint256): payable
//     def calc_withdraw_one_coin(token_amount: uint256, i: uint256) -> uint256: view
//     def remove_liquidity_one_coin(token_amount: uint256, i: uint256, min_amount: uint256): nonpayable
interface ICryptoPool {
    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external payable returns (uint256);
    function coins(uint256 index) external view returns (address);
    function get_dy(uint256 i, uint256 j, uint256 amount) external view returns (uint256);
}
