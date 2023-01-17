// SPDX-License-Identifier: GPL-3.0
/**
 * FeeToInterface interface
 */
pragma solidity ^0.8.0;


import "../Libraries/CommitteeSet.sol";

interface CommitteeInterface {

    // Signatrue infomation 
    // make address and uint8 to 1 slot
    struct Signature {
        address signatory;
        uint8   v;
        bytes32 r;
        bytes32 s;
    }

    /**
     * @dev add/remove member from commitee
     * 
     * Params
     * - address member 
     * - string method
     * - uint256 date
     */ 
    event CommiteeMemberChange(
        address member, 
        string method, 
        uint256 date
    );

    /**
     * @dev Log fee address change
     * 
     * Params
     * - oldSigsMin 
     * - sigsMin
     * - date block.timestamp
     */ 
    event SetMinimumSigs(uint256 oldSigsMin, uint sigsMin, uint256 date);


    /**
     * @dev run setperform by sigs 
     * 
     * Params:
     * - Signature[] calldata sigs : commitee signatures
     * - swap swap address
     * - newPerformer new performer address
     * - deadline signatrue deadline
     */ 
    function setPerformBySigs(
        Signature[] calldata sigs, 
        address swap,
        address newPerformer, 
        uint256 deadline
    ) external;

    /*
     * @dev check setFeeTo sigs 
     * 
     * Params:
     * - Signature[] calldata sigs : commitee signatures
     * - performer performer address
     * - newFeeTo new feeTo address
     * - deadline signatrue deadline
     * 
     * Returns:
     * - bool true
     */
    function setFeeToBySigs(
        Signature[] calldata sigs, 
        address performer,
        address newFeeTo, 
        uint256 deadline
    ) external;

    /**
     * @dev run setFeeRate by sigs 
     * 
     * Params:
     * - Signature[] calldata sigs : commitee signatures
     * - performer performer address
     * - newFeeRate new fee rate 
     * - deadline signatrue deadline
     */ 
    function setFeeRateBySigs(
        Signature[] calldata sigs, 
        address performer,
        uint256 newFeeRate, 
        uint256 deadline
    ) external;

    /**
     * @dev run transfer contract owner by sigs 
     * 
     * Params:
     * - Signature[] calldata sigs : commitee signatures
     * - address ownerContract: a contract which needs to transfer owner by address(this)
     * - address newOwner 
     * - deadline signatrue deadline
     */
    function transferContractOwnerBySigs(
        Signature[] calldata sigs, 
        address ownerContract,
        address newOwner, 
        uint256 deadline
    ) external;

    /**
     * @dev it's a dangerous function, will run some code human disreadable 
     * 
     * Params:
     * - Signature[] calldata sigs : commitee signatures
     * - address theContract: a contract which runs bytecode
     * - bytes calldata bytecode: human disreadable code
     * - deadline signatrue deadline
     */
    function functionCallBySigs(
        Signature[] calldata sigs, 
        address theContract,
        bytes calldata bytecode, 
        uint256 deadline
    ) external;

    /**
     * @dev add commitee member
     * 
     * Params:
     * - ..
     * - address newMember
     */
    function addCommiteeMember(Signature[] calldata sigs, uint256 deadline, address newMemberWallet) external;

    /**
     * @dev remove commitee member
     * 
     * Params:
     * - ..
     * - address member
     */
    function removeCommiteeMember(Signature[] calldata sigs, uint256 deadline, address memberWallet) external;

    /**
     * @dev set commitee member sinatrue minimal number
     * 
     * Params:
     * - ..
     * - uint newMinimumSigs
     */
    function setMinimumSigs(Signature[] calldata sigs, uint256 deadline, uint256 newMinimumSigs) external ;

    /**
     * @dev upgrade committee contract
     * 
     * Params:
     * - ..
     * - uint newMinimumSigs
     */
    function upgradeToBySigs(Signature[] calldata sigs, uint256 deadline, address implementation) external;
}