// SPDX-License-Identifier: BlueOak-1.0.0
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "contracts/plugins/assets/AppreciatingFiatCollateral.sol";
import "contracts/plugins/rocket-eth/IReth.sol";
import "contracts/plugins/assets/OracleLib.sol";
import "contracts/libraries/Fixed.sol";

/**
 * @title RethCollateral
 * @notice Collateral plugin for Rocket-Pool ETH,
 * tok = rETH
 * ref = ETH
 * tar = ETH
 * UoA = USD
 */
contract RethCollateral is AppreciatingFiatCollateral {
    using OracleLib for AggregatorV3Interface;
    using FixLib for uint192;

    AggregatorV3Interface public refPerTokChainlinkFeed;
    uint48 public refPerTokChainlinkTimeout;

    constructor(
        CollateralConfig memory config,
        uint192 revenueHiding,
        AggregatorV3Interface _refPerTokChainlinkFeed,
        uint48 _refPerTokChainlinkTimeout
    ) AppreciatingFiatCollateral(config, revenueHiding) {
        require(address(_refPerTokChainlinkFeed) != address(0), "Chainlink feed cannot be 0x0");
        require(_refPerTokChainlinkTimeout != 0, "Chainlink feed cannot be 0x0");
        refPerTokChainlinkFeed = _refPerTokChainlinkFeed;
        refPerTokChainlinkTimeout = _refPerTokChainlinkTimeout;
        exposedReferencePrice = _underlyingRefPerTok().mul(revenueShowing);
    }

    /// Can revert, used by other contract functions in order to catch errors
    /// @return low {UoA/tok} The low price estimate
    /// @return high {UoA/tok} The high price estimate
    /// @return pegPrice {target/ref}
    function tryPrice()
        external
        view
        override
        returns (
            uint192 low,
            uint192 high,
            uint192 pegPrice
        )
    {
        uint192 p = chainlinkFeed.price(oracleTimeout); // target==ref :: {UoA/target} == {UoA/ref}

        // use market price for {ref/tok}
        pegPrice = refPerTokChainlinkFeed.price(refPerTokChainlinkTimeout);

        // {UoA/tok} = {UoA/ref} * {ref/tok}
        uint192 pLow = p.mul(pegPrice.mul(revenueShowing));

        // {UoA/tok} = {UoA/ref} * {ref/tok}
        uint192 pHigh = p.mul(pegPrice);

        low = pLow - pLow.mul(oracleError);
        high = pHigh + pHigh.mul(oracleError);
    }

    /// @return {ref/tok} Quantity of whole reference units per whole collateral tokens
    function _underlyingRefPerTok() internal view override returns (uint192) {
        return _safeWrap(IReth(address(erc20)).getExchangeRate());
    }
}
