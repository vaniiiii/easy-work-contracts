// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";
import "@ethereum-attestation-service/eas-contracts/contracts/ISchemaRegistry.sol";
import "./PayingResolver.sol";

// TO-DO:
// - add events
// - add tests

contract EASYWork is Ownable2Step {
    // custom types
    enum Status {
        None,
        Created,
        Active,
        Finished,
        Canceled
    }

    // stateVariables
    uint256 public totalGigs;
    bytes32 public immutable descriptionGigSchemaId;
    bytes32 public immutable gigSchemaId;
    mapping(bytes32 => Status) public gigStatus;

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
    error EASYWork__CanNotCancelActiveGig();
    error EASYWork__CanNotFinishNonActiveGig();

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
        // add more input validation, like recipient check request.data.recipient == msg.sender
        bytes32 uid = eas.attest(request);
        gigStatus[uid] = Status.Created;
    }

    function assignGig(bytes32 uid, AttestationRequest calldata request) external payable {
        if (gigStatus[uid] == Status.Active) {
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

        (address freelancer,) = decodeGigAttestationData(request.data.data);
        if (freelancer == address(0)) {
            revert EASYWork__ZeroAddress();
        }

        (,,, uint256 price,) = decodeDescriptionGigAttestationData(attestation.data);
        if (msg.value < price) {
            revert EASYWork__InsufficientFunds();
        }

        gigStatus[uid] = Status.Active;

        payingResolver.setGigPrice(uid, price);

        eas.attest(request);

        (bool sent,) = payable(address(payingResolver)).call{value: msg.value}("");
        if (!sent) {
            revert EASYWork__InsufficientFunds();
        }
    }

    function finishGig(bytes32 uid, AttestationRequest calldata request) external {
        if (gigStatus[uid] != Status.Active) {
            revert EASYWork__CanNotFinishNonActiveGig();
        }

        Attestation memory attestation = eas.getAttestation(uid);

        if (attestation.recipient != msg.sender || attestation.attester != address(this)) {
            revert EASYWork__NotAuthorized();
        }

        if (request.data.refUID != uid) {
            revert EASYWork__WrongRefUId();
        }

        gigStatus[uid] = Status.Active;
        eas.attest(request); // attest to freelancer

        // add penalty if it's late, further versions
    }

    function cancelGig(bytes32 uid) external {
        if (gigStatus[uid] != Status.Created) {
            revert EASYWork__CanNotCancelActiveGig();
        }
        Attestation memory attestation = eas.getAttestation(uid);
        if (attestation.recipient != msg.sender || attestation.attester != address(this)) {
            revert EASYWork__NotAuthorized();
        }
        gigStatus[uid] = Status.Canceled;
        payingResolver.withdrawGigDeposit(uid, msg.sender); // ovo ti ne treba?
    }

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

    function decodeGigAttestationData(bytes memory data)
        internal
        pure
        returns (address freelancer, string memory description)
    {
        (freelancer, description) = abi.decode(data, (address, string));
    }
}

interface IPayingResolver {
    function setGigPrice(bytes32 gigId, uint256 gigPrice) external;
    function withdrawGigDeposit(bytes32 uid, address recipient) external;
}
