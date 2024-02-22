// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Mosquito is ERC20 {
    address public owner;

    // Tax rates
    uint256 public taxFee = 4;
    uint256 public liquidityFee = 3;
    
    // Liquidity pool address 
    address public liquidityPool;

    // Maximum transaction amount (0.1% of total supply)
    uint256 public maxTxAmount;
    bool public maxTxEnabled = false; // Initially disabled
    bool public maxTxSet = false; // Flag to track if maxTxEnabled has been set

    // Addresses excluded from fees
    mapping(address => bool) private _isExcludedFromFees;
    
    // Addresses excluded from max transaction limit
    mapping(address => bool) private _isExcludedFromMaxTx;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    constructor(address _liquidityPool) ERC20("Mosquito", "Mosquito") {
        owner = msg.sender;
        liquidityPool = _liquidityPool;
        maxTxAmount = 1000000 * 10**18; // Initial transfer not subject to limit
        _mint(owner, 1000000 * 10**18); // Total supply set to 1000 tokens
        emit Transfer(address(0), owner, 1000000 * 10**18);
    }

    // Function to enable maxTxEnabled after initial transfer
    function enableMaxTx() external onlyOwner {
        require(!maxTxSet, "maxTxEnabled has already been set");
        maxTxEnabled = true;
        maxTxAmount = totalSupply() / 1000; // 0.1% of total supply
        maxTxSet = true; // Set the flag
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, allowance(sender, msg.sender) - amount);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) private {
        require(sender != address(0), "Transfer from the zero address");
        require(recipient != address(0), "Transfer to the zero address");
        require(amount <= balanceOf(sender), "Transfer amount exceeds balance");
        
        // Check if maxTxEnabled is set and apply max transaction limit if enabled
        if (maxTxEnabled && !_isExcludedFromMaxTx[sender] && !_isExcludedFromMaxTx[recipient]) {
            require(amount <= maxTxAmount, "Transfer amount exceeds the max transaction amount");
        }
        
        // Check if sender or recipient is excluded from fees
        bool takeFee = !_isExcludedFromFees[sender] && !_isExcludedFromFees[recipient];
        
        // Calculate taxes if applicable
        if (takeFee) {
            uint256 taxAmount = amount * taxFee / 100;
            uint256 liquidityAmount = amount * liquidityFee / 100;
            uint256 tokensToTransfer = amount - taxAmount - liquidityAmount;

            // Transfer tokens
            _transfer(sender, recipient, tokensToTransfer);
            _transfer(sender, liquidityPool, liquidityAmount);
            _transfer(sender, address(this), taxAmount);
        } else {
            // Transfer tokens without tax
            _transfer(sender, recipient, amount);
        }
    }

    function addToFeeWhitelist(address account) external onlyOwner {
        _isExcludedFromFees[account] = true;
    }

    function removeFromFeeWhitelist(address account) external onlyOwner {
        _isExcludedFromFees[account] = false;
    }

    function addToMaxTxWhitelist(address account) external onlyOwner {
        _isExcludedFromMaxTx[account] = true;
    }

    function removeFromMaxTxWhitelist(address account) external onlyOwner {
        _isExcludedFromMaxTx[account] = false;
    }
}
