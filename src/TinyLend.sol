// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

contract TinyLend {
    /* ---------- fixed-point helpers ---------- */
    uint256 private constant RAY = 1e27;         // 27-decimals

    /* ---------- storage ---------- */
    struct Market {
        uint256 supplyAcc;          // starts at RAY
        uint256 borrowAcc;          // starts at RAY
        uint256 totalSupplyShares;
        uint256 totalBorrowShares;
        uint256 totalBorrowUnderlying;  // cache 
        uint256 lastAccrual;
    }

    struct Account {
        uint256 supplyShares;
        uint256 borrowShares;
    }

    mapping(address collateral => Market) public markets;
    mapping(address user => mapping(address collateral => Account)) public accounts;

    /* ---------- external user actions ---------- */

    /// @notice deposit `amt` of `col` and receive supply-shares
    function deposit(address col, uint256 amt) external { 
        _accrue(col);

        Market storage m = markets[col];

        Account storage a = accounts[msg.sender][col];

        uint256 shares = (amt * RAY) / m.supplyAcc;   
        a.supplyShares      += shares;
        m.totalSupplyShares += shares;

        // transfer tokens in
        require(IERC20(col).transferFrom(msg.sender, address(this), amt), "transfer failed");
    }

    /// @notice withdraw `amt` of `col`, burning supply-shares
    function withdraw(address col, uint256 amt) external {
        _accrue(col);

        Market  storage m = markets[col];
        Account storage a = accounts[msg.sender][col];

        uint256 shares = (amt * RAY + m.supplyAcc - 1) / m.supplyAcc; // round up
        a.supplyShares      -= shares;
        m.totalSupplyShares -= shares;

        // transfer tokens out
        require(IERC20(col).transfer(msg.sender, amt), "transfer failed");
    }

    /// @notice borrow `amt` of `col`, receiving underlying and minting debt-shares
    function borrow(address col, uint256 amt) external {
        _accrue(col);

        Market  storage m = markets[col];
        Account storage a = accounts[msg.sender][col];

        uint256 shares = (amt * RAY) / m.borrowAcc;
        a.borrowShares      += shares;
        m.totalBorrowShares += shares;
        m.totalBorrowUnderlying += amt;

        // transfer tokens out
        require(IERC20(col).transfer(msg.sender, amt), "transfer failed");
    }

    /// @notice repay up to `amt` of `col` debt; use type(uint256).max to repay all
    function repay(address col, uint256 amt) external {
        _accrue(col);

        Market  storage m = markets[col];
        Account storage a = accounts[msg.sender][col];

        // if caller wants to repay everything, figure out their total debt first
        uint256 underlyingOwed = a.borrowShares * m.borrowAcc / RAY;
        if (amt == type(uint256).max) amt = underlyingOwed;
        require(amt > 0, "nothing to repay");
        require(amt <= underlyingOwed, "repay more than owed");

        // burn the corresponding borrow-shares (round up so we never leave dust)
        uint256 shares = (amt * RAY + m.borrowAcc - 1) / m.borrowAcc;
        a.borrowShares      -= shares;
        m.totalBorrowShares -= shares;
        m.totalBorrowUnderlying -= amt;

        // transfer tokens in
        require(IERC20(col).transferFrom(msg.sender, address(this), amt), "transfer failed");
    }

    /* ---------- view helpers ---------- */

    function suppliedUnderlying(address u, address col) external view returns (uint256) {
        Market  storage m = markets[col];
        Account storage a = accounts[u][col];
        return a.supplyShares * m.supplyAcc / RAY;
    }

    function borrowedUnderlying(address u, address col) external view returns (uint256) {
        Market  storage m = markets[col];
        Account storage a = accounts[u][col];
        return a.borrowShares * m.borrowAcc / RAY;
    }

    /* ---------- core: interest accrual ---------- */

    function _accrue(address col) internal { 

        Market storage m  = markets[col];

        // initialize market if it doesn't exist
        if (m.lastAccrual == 0) {
            m.supplyAcc = RAY;
            m.borrowAcc = RAY;
            m.lastAccrual = block.timestamp;
        }

        uint256   dt     = block.timestamp - m.lastAccrual;
        if (dt == 0) return;

        // 1. accrue interest on outstanding borrows
        uint256 borrowRate = _getBorrowRate(col);           // ray per second
        uint256 factor     = RAY + borrowRate * dt;         // simple interest

        uint256 prevBorrowAcc = m.borrowAcc;
        m.borrowAcc = prevBorrowAcc * factor / RAY;         // grows

        uint256 deltaBorrow =
            m.totalBorrowUnderlying * (factor - RAY) / RAY; // ≈ r·Δt·B
        m.totalBorrowUnderlying += deltaBorrow;

        // 2. transfer interest -> suppliers 
        if (m.totalSupplyShares > 0) {
            m.supplyAcc += deltaBorrow * RAY / m.totalSupplyShares;
        }

        m.lastAccrual = block.timestamp;
    }

    /* ---------- stub interest-rate model ---------- */
    function _getBorrowRate(address) internal pure returns (uint256) {
        return uint256(5e24) / 365 days; // 5 % APR expressed in ray-per-second
    }
}
