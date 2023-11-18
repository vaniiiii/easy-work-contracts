// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import {SchemaResolver} from "@ethereum-attestation-service/eas-contracts/contracts/resolver/SchemaResolver.sol";

import {IEAS, Attestation} from "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";

/**
 * @title A sample schema resolver that pays attesters (and expects the payment to be returned during revocations)
 */
contract PayingResolver is SchemaResolver {
    error InvalidValue();

    uint256 gigPrice;

    constructor(IEAS eas) SchemaResolver(eas) {}

    function isPayable() public pure override returns (bool) {
        return true;
    }

    function setGigPrice(uint256 gigPrice_) external {
        gigPrice = gigPrice_;
    }

    function onAttest(Attestation calldata attestation, uint256 value) internal override returns (bool) {
        if (value > 0) {
            return false;
        }

        payable(attestation.recipient).transfer(gigPrice);

        return true;
    }

    function onRevoke(Attestation calldata, /*attestation*/ uint256 /*value*/ ) internal pure override returns (bool) {
        return true;
    }
}
