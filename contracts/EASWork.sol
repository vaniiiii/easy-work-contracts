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
    // state variables
    uint256 public totalGigs;
    // struct Gig

    // is this Attestation? shall we add schema field?
    struct Gig {
        uint256 id;
        address payable client;
        address payable freelancer;
        uint256 price;
    }
    // address resolver;
    // uint256 deadline;
    // string description;
    // string schema;

    Gig[] public gigs;

    IPayingResolver public immutable payingResolver;
    IEAS public immutable eas;
    ISchemaRegistry public immutable schemaRegistry;

    error EASYWork__Not_Authorized();
    error EASYWork__Gig_Already_Assigned();

    constructor(address eas_, address schemaRegistry_, address payingResolver_) {
        eas = IEAS(eas_);
        schemaRegistry = ISchemaRegistry(schemaRegistry_);
        payingResolver = IPayingResolver(payingResolver_);
    }

    function createSchema(string calldata schema, ISchemaResolver resolver, bool revocable) external onlyOwner {
        schemaRegistry.register(schema, resolver, revocable);
    }

    function createGig(uint256 gigPrice) external {
        Gig memory gig =
            Gig({id: totalGigs, client: payable(msg.sender), freelancer: payable(address(0)), price: gigPrice});

        gigs.push(gig);

        unchecked {
            ++totalGigs;
        }
    }

    // potentially push this in pending array for freelancer to accept
    function assignGig(uint256 gigId, address freelancer) external {
        Gig memory gig = gigs[gigId];

        if (gig.freelancer != address(0)) {
            revert EASYWork__Gig_Already_Assigned();
        }
        if (msg.sender != gig.client) {
            revert EASYWork__Not_Authorized();
        }
        // transfer money to paying resolver missing
        // create GigAttestation
        gigs[gigId].freelancer = payable(freelancer);
    }

    function closeGig(uint256 gigId, AttestationRequest calldata request) external {
        Gig memory gig = gigs[gigId];

        if (msg.sender != gig.client) {
            revert EASYWork__Not_Authorized();
        }

        gig.freelancer = payable(address(0));

        payingResolver.setGigPrice(gig.price);
        // create GigAttestation missing

        eas.attest(request); // attest to freelancer
    }
}

interface IPayingResolver {
    function setGigPrice(uint256 gigPrice_) external;
}

/*
 ["0x3b998ad03fa9b67e797d2c8a5d6fd859c53d12a9026c604dc8fb62da06bc4c70",["0x11c40aDc460a53F4f3Ac6fb18dd06fC72dBd40c8",0,false,"0x0000000000000000000000000000000000000000000000000000000000000000","0x0000000000000000000000000000000000000000000000000000000000000000",0]]
*/
