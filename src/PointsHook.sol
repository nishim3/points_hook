// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDeltaLibrary, BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

contract PointsHook is BaseHook, ERC20 {
    using CurrencyLibrary for Currency;
    using BalanceDeltaLibrary for BalanceDelta;

    mapping(address => address) public referredBy;

    uint256 public constant POINTS_FOR_REFERRAL = 500 * 10 ** 18;

    constructor(IPoolManager manager, string memory _name, string memory _symbol)
        BaseHook(manager)
        ERC20(_name, _symbol, 18)
    {}

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterAddLiquidity: true,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function getHookData(address referrer, address referree) public pure returns (bytes memory) {
        return abi.encode(referrer, referree);
    }

    function _assignPoints(bytes calldata hookData, uint256 referreePoints) internal {
        if (hookData.length == 0) return;

        (address referrer, address referree) = abi.decode(hookData, (address, address));

        if (referree == address(0)) return;

        if (referredBy[referree] == address(0) && referrer != address(0)) {
            referredBy[referree] = referrer;
            _mint(referrer, POINTS_FOR_REFERRAL);
        }

        if (referredBy[referree] != address(0)) {
            _mint(referrer, referreePoints / 10);
        }

        _mint(referree, referreePoints);
    }

    //hook functions
    function afterSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata swapParams,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override onlyByPoolManager returns (bytes4, int128) {
        if (!key.currency0.isNative()) return (this.afterSwap.selector, 0); // reject non native pools
        if (!swapParams.zeroForOne) return (this.afterSwap.selector, 0); // only if buying tokens (giveing eth, taking token)

        uint256 ethSpent = uint256(int256(-delta.amount0()));
        uint256 pointsForSwap = ethSpent/5;

        _assignPoints(hookData, pointsForSwap);
        return (this.afterSwap.selector, 0);
    }
}
