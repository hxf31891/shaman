// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBEP20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Mosquito is IBEP20 {
    string public name = "Mosquito";
    string public symbol = "Mosquito";
    uint8 public decimals = 18;
    uint256 private _totalSupply = 1000000 * 10**18; // Total supply set to 1000 tokens
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
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

    constructor(address _liquidityPool) {
        _balances[msg.sender] = _totalSupply;
        owner = msg.sender;
        liquidityPool = _liquidityPool;
        maxTxAmount = _totalSupply; // Initial transfer not subject to limit

        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    // Function to enable maxTxEnabled after initial transfer
    function enableMaxTx() external onlyOwner {
        require(!maxTxSet, "maxTxEnabled has already been set");
        maxTxEnabled = true;
        maxTxAmount = _totalSupply / 1000; // 0.1% of total supply
        maxTxSet = true; // Set the flag
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address _owner, address spender) external view override returns (uint256) {
        return _allowances[_owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender] - amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] - subtractedValue);
        return true;
    }

    // Function to add an address to the whitelist to exclude it from transaction fees
    function addToFeeWhitelist(address account) external onlyOwner {
        _isExcludedFromFees[account] = true;
    }

    // Function to remove an address from the whitelist
    function removeFromFeeWhitelist(address account) external onlyOwner {
        _isExcludedFromFees[account] = false;
    }

    // Function to whitelist an address from the maximum transaction limit
    function addToMaxTxWhitelist(address account) external onlyOwner {
        _isExcludedFromMaxTx[account] = true;
    }

    // Function to remove an address from the maximum transaction limit whitelist
    function removeFromMaxTxWhitelist(address account) external onlyOwner {
        _isExcludedFromMaxTx[account] = false;
    }

    function _approve(address _owner, address spender, uint256 amount) private {
        require(_owner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");
        _allowances[_owner][spender] = amount;
        emit Approval(_owner, spender, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) private {
        require(sender != address(0), "BEP20: transfer from the zero address");
        require(recipient != address(0), "BEP20: transfer to the zero address");
        require(amount <= _balances[sender], "BEP20: transfer amount exceeds balance");
        
        // Check if maxTxEnabled is set and apply max transaction limit if enabled
        if (maxTxEnabled && !_isExcludedFromMaxTx[sender] && !_isExcludedFromMaxTx[recipient]) {
            require(amount <= maxTxAmount, "BEP20: transfer amount exceeds the max transaction amount");
        }
        
        // Check if sender or recipient is excluded from fees
        bool takeFee = !_isExcludedFromFees[sender] && !_isExcludedFromFees[recipient];
        
        // Calculate taxes if applicable
        if (takeFee) {
            uint256 taxAmount = amount * taxFee / 100;
            uint256 liquidityAmount = amount * liquidityFee / 100;
            uint256 tokensToTransfer = amount - taxAmount - liquidityAmount;

            // Transfer tokens
            _balances[sender] -= amount;
            _balances[recipient] += tokensToTransfer;

            // Transfer tax to liquidity pool
            _balances[liquidityPool] += liquidityAmount;

            // Distribute tax to current holders
            _balances[address(this)] += taxAmount;

            emit Transfer(sender, recipient, tokensToTransfer);
            emit Transfer(sender, liquidityPool, liquidityAmount);
            emit Transfer(sender, address(this), taxAmount);
        } else {
            // Transfer tokens without tax
            _balances[sender] -= amount;
            _balances[recipient] += amount;
            emit Transfer(sender, recipient, amount);
        }
    }
}
