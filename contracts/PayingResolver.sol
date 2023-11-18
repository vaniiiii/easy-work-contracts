// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

import {SchemaResolver} from "@ethereum-attestation-service/eas-contracts/contracts/resolver/SchemaResolver.sol";

import {IEAS, Attestation} from "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";

/**
 * @title A sample schema resolver that pays attesters (and expects the payment to be returned during revocations)
 */
contract PayingResolver is SchemaResolver, Ownable2Step {
    address easywork;
    mapping(uint256 => uint256) public gigPrices;

    error PayingResolver__NotAuthorzed();
    error PayingResolver__PriceAlreadySet();

    modifier onlyEASYWork() {
        if (msg.sender != easywork) {
            revert PayingResolver__NotAuthorzed();
        }
        _;
    }

    constructor(IEAS eas) SchemaResolver(eas) {}

    function setEasyWork(address easywork_) external onlyOwner {
        easywork = easywork_;
    }

    function setGigPrice(uint256 gigId, uint256 gigPrice) external onlyEASYWork {
        if (gigPrices[gigId] != 0) {
            revert PayingResolver__PriceAlreadySet();
        }
        gigPrices[gigId] = gigPrice;
    }

    function isPayable() public pure override returns (bool) {
        return true;
    }

    function onAttest(Attestation calldata attestation, uint256 value) internal override returns (bool) {
        if (value > 0) {
            return false;
        }
        if (attestation.attester != easywork) {
            return false;
        }
        // change this
        uint256 gigPrice = gigPrices[uint256(attestation.refUID)];
        gigPrices[uint256(attestation.refUID)] = 0;

        payable(attestation.recipient).transfer(gigPrice);

        return true;
    }

    function onRevoke(Attestation calldata, /*attestation*/ uint256 /*value*/ ) internal pure override returns (bool) {
        return true;
    }

    function withdrawGigDeposit(uint256 gigId, address recipient) external onlyEASYWork {
        uint256 price = gigPrices[gigId];
        gigPrices[gigId] = 0;

        payable(recipient).transfer(price);
    }
}
