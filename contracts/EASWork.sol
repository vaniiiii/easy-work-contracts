// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";
import "@ethereum-attestation-service/eas-contracts/contracts/ISchemaRegistry.sol";
import "./PayingResolver.sol";

// TO-DO:
// - add schema field to Gig struct
// - add withdraw functionallity
// - add more fields to indicate if job is active/finished/whatever
// - add events
// - add tests

contract EASYWork is Ownable2Step {
    // stateVariables
    uint256 public totalGigs;
    bytes32 public immutable descriptionGigSchemaId;
    bytes32 public immutable gigSchemaId;
    mapping(bytes32 => bool) public gigAssigned;

    // interfaces
    IPayingResolver public immutable payingResolver;
    IEAS public immutable eas;
    ISchemaRegistry public immutable schemaRegistry;

    // customErrors
    error EASYWork__WrongSchema();
    error EASYWork__NotAuthorized();
    error EASYWork__ZeroAddress();
    error EASYWork__GigAlreadyAssigned();
    error EASYWork__WrongRefUId();
    error EASYWork__InsufficientFunds();

    constructor(
        bytes32 descriptionGigSchemaId_,
        bytes32 gigSchemaId_,
        address eas_,
        address schemaRegistry_,
        address payingResolver_
    ) {
        descriptionGigSchemaId = descriptionGigSchemaId_;
        gigSchemaId = gigSchemaId_;
        eas = IEAS(eas_);
        schemaRegistry = ISchemaRegistry(schemaRegistry_);
        payingResolver = IPayingResolver(payingResolver_);
    }

    function createSchema(string calldata schema, ISchemaResolver resolver, bool revocable) external onlyOwner {
        schemaRegistry.register(schema, resolver, revocable);
    }

    function createGig(AttestationRequest calldata request) external {
        if (request.schema != descriptionGigSchemaId) {
            revert EASYWork__WrongSchema();
        }
        unchecked {
            ++totalGigs;
        }
        eas.attest(request);
    }

    function assignGig(bytes32 uid, AttestationRequest calldata request) external payable {
        if (gigAssigned[uid]) {
            revert EASYWork__GigAlreadyAssigned();
        }

        Attestation memory attestation = eas.getAttestation(uid);

        if (attestation.recipient != msg.sender || attestation.attester != address(this)) {
            revert EASYWork__NotAuthorized();
        }
        if (request.schema != gigSchemaId) {
            revert EASYWork__WrongSchema();
        }
        if (request.data.refUID != uid) {
            revert EASYWork__WrongRefUId();
        }

        address freelancer = decodeGigAttestationData(request.data.data);
        if (freelancer == address(0)) {
            revert EASYWork__ZeroAddress();
        }

        (,,, uint256 price,) = decodeDescriptionGigAttestationData(attestation.data);
        if (msg.value < price) {
            revert EASYWork__InsufficientFunds();
        }

        gigAssigned[uid] = true;

        eas.attest(request);
        (bool sent,) = payable(address(payingResolver)).call{value: msg.value}("");
        if (!sent) {
            revert EASYWork__InsufficientFunds();
        }
    }

    /*
    function closeGig(uint256 gigId, AttestationRequest calldata request) external {
        Gig memory gig = gigs[gigId];

        if (msg.sender != gig.client) {
            revert EASYWork__Not_Authorized();
        }

        gig.freelancer = payable(address(0));

        payingResolver.setGigPrice(gig.price);
        // create GigAttestation missing
        // input validation
        // add penalty if it's late

        eas.attest(request); // attest to freelancer
    }
    */

    function decodeDescriptionGigAttestationData(bytes memory data)
        internal
        pure
        returns (
            string memory jobTitle,
            string memory category,
            uint256 deadline,
            uint256 price,
            string memory description
        )
    {
        (jobTitle, category, deadline, price, description) =
            abi.decode(data, (string, string, uint256, uint256, string));
    }

    function decodeGigAttestationData(bytes memory data) internal pure returns (address freelancer) {
        assembly {
            freelancer := mload(add(data, 0x20))
        }
    }
}

interface IPayingResolver {
    function setGigPrice(uint256 gigPrice_) external;
}

/*
 ["0x3b998ad03fa9b67e797d2c8a5d6fd859c53d12a9026c604dc8fb62da06bc4c70",["0x11c40aDc460a53F4f3Ac6fb18dd06fC72dBd40c8",0,false,"0x0000000000000000000000000000000000000000000000000000000000000000","0x0000000000000000000000000000000000000000000000000000000000000000",0]]
*/
