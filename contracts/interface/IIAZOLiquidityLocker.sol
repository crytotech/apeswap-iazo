//SPDX-License-Identifier: UNLICENSED
//ALL RIGHTS RESERVED
//apeswap.finance

import "./ERC20.sol";

pragma solidity 0.8.6;

interface IIAZOLiquidityLocker {
    function APE_FACTORY() external view returns (address);

    function IAZO_EXPOSER() external view returns (address);

    function isIAZOLiquidityLocker() external view returns (bool);

    function owner() external view returns (address);

    function renounceOwnership() external;

    function transferOwnership(address newOwner) external;

    function apePairIsInitialised(address _token0, address _token1)
        external
        view
        returns (bool);

    function lockLiquidity(
        ERC20 _baseToken,
        ERC20 _saleToken,
        uint256 _baseAmount,
        uint256 _saleAmount,
        uint256 _unlock_date,
        address _withdrawer,
        address _iazoAddress
    ) external returns (address);
}
