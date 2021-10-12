//SPDX-License-Identifier: UNLICENSED
//ALL RIGHTS RESERVED
//apeswap.finance
pragma solidity 0.8.6;

import "./ERC20.sol";

interface IIAZOLiquidityLocker {
    function APE_FACTORY() external view returns (address);

    function IAZO_EXPOSER() external view returns (address);

    function isIAZOLiquidityLocker() external view returns (bool);

    function owner() external view returns (address);

    function renounceOwnership() external;

    function transferOwnership(address newOwner) external;

    function apePairIsInitialized(address _token0, address _token1)
        external
        view
        returns (bool);

    function lockLiquidity(
        ERC20 _baseToken,
        ERC20 _saleToken,
        uint256 _baseAmount,
        uint256 _saleAmount,
        uint256 _unlockDate,
        address _withdrawer
    ) external returns (address);
}
