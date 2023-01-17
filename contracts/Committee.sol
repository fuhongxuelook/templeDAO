// SPDX-License-Identifier: GPL-3.0
/**
 * @dev multisig for commitee to do some critical transaction
 * 
 * like set performer address and set feeTo address
 */

pragma solidity ^0.8.0;

import "./Interface/CommitteeInterface.sol";
import "./Interface/SwapInterface.sol";
import "./Interface/FeeToInterface.sol";
import "./Interface/AdapterManageInterface.sol";
import "./Interface/OwnerInterface.sol";
import "./Interface/IERC20.sol";
import "./Libraries/TransferHelper.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


contract Committee is  CommitteeInterface, EIP712Upgradeable, UUPSUpgradeable {    

    using AddressUpgradeable for address;
    using TransferHelper for address;
    using CommitteeSet for CommitteeSet.Set;

    CommitteeSet.Set commitee;

    // minimal signature number
    uint256 public minimumSigs;

    // prevert reentrancy
    uint256 public nonces;

    // function call cant run this 
    mapping(bytes4 => bool) selectors;

    // committee status
    mapping(address => bool) committeeStatus;


    // SetPerformer(address swap,address performer,uint256 chainId,uint256 nonce,uint256 deadline)
    // type struct
    // there are not space after comma
    // to guarentee runing on right chain, we neeed chainId,
    // nonce to prevert reentenry call, must need a nonce
    // deadline to guarentee the signatrue is time limited
    // this contract execute not frequently, so, choose original code 

    // keccak256("SetPerformer(address swap,address performer,uint256 chainId,uint256 nonce,uint256 deadline)");
    bytes32 constant TypeSetPerformerHash = 0x29570a74fc215c30669309b6ab3fd6bfc183f0b11360dd0a16f7b9caa246908f;

    // keccak256("SetFeeTo(address performer,address feeTo,uint256 chainId,uint256 nonce,uint256 deadline)");
    bytes32 constant TypeSetFeeToHash = 0x347121c6281ff657d180ee48d2f8ef60b2fc42d3a65bb29b0f383fed46471f39;

    // keccak256("SetFeeRate(address performer,uint256 feeRate,uint256 chainId,uint256 nonce,uint256 deadline)");
    bytes32 constant TypeSetFeeRateHash = 0x5f1ba42d59312596efd461ad7b4a7e373fd3d3a10c3e69fe17fd27f053a17458;

    // keccak256("TransferOwner(address ownerContract,address newOwner,uint256 chainId,uint256 nonce,uint256 deadline)");
    bytes32 constant TypeTransferOwnerHash = 0xc1f779e5a791decdc33abca8b31ea84a45395e053f13297cbf2b7c2a03edcad5;

    // keccak256("FunctionCall(address theContract,bytes32 bytecodeHash,uint256 chainId,uint256 nonce,uint256 deadline)");
    bytes32 constant TypeFunctionCallHash = 0x62d993eb7054d9a416e2938b405af11dc2622c21a603e17677a4eae94bb42ae3;

    // keccak256("CommitteeConfig(bytes4 selector,uint256 chainId,uint256 nonce,uint256 deadline)");
    bytes32 constant TypeCommitteeConfigHash = 0xafbacfc50e735036d6170033fdd0b81f7c84a34a235bf7fdd5f58ca394669832;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __EIP712_init("SAVI", "1.0");

        CommitteeSet.Member memory member = CommitteeSet.Member(msg.sender);
        commitee.add(member);

        minimumSigs = 1;
    }

    /// committee validation
    modifier onlyCommittee() {
        require(commitee.exists(msg.sender), "Committee::onlyCommittee : Caller must be commitee member");
        _;
    }

    /**
     * @dev See MultiSigInterface - setPerformBySigs
     * 
     * Requirements:
     * - sigs number must large minimumSigs
     * 
     * - dealline less than block timestamp
     * 
     * - signature address must equal recoverred address
     * 
     * - signature address must belongs to commitee
     */ 
    function setPerformBySigs(
        Signature[] calldata sigs, 
        address swap,
        address newPerformer, 
        uint256 deadline
    ) external override onlyCommittee {
        
        require(deadline >= block.timestamp, "Committee::setPerformBySigs : Signatrue is timeout");

        // genetate struct data hash
        bytes32 typeDataHash = keccak256(abi.encode(TypeSetPerformerHash, swap, newPerformer, block.chainid, nonces++, deadline));

        // hash Type data
        bytes32 hashedTypeData = _hashTypedDataV4(typeDataHash);

        _validateSigsByteTypedData(sigs, hashedTypeData);

        SwapInterface(swap).setPerformer(newPerformer);

    }

    /**
     * @dev See MultiSigInterface - setFeeToBySigs
     * 
     * Requirements:
     * - ..
     */ 
    function setFeeToBySigs(
        Signature[] calldata sigs, 
        address performer,
        address newFeeTo, 
        uint256 deadline
    ) external override onlyCommittee {
        
        require(deadline >= block.timestamp, "Committee::setFeeToBySigs : Signatrue is timeout");

        // genetate struct data hash
        bytes32 typeDataHash = keccak256(abi.encode(TypeSetFeeToHash, performer, newFeeTo, block.chainid, nonces++, deadline));

        // hash Type data
        bytes32 hashedTypeData = _hashTypedDataV4(typeDataHash);

         _validateSigsByteTypedData(sigs, hashedTypeData);

        FeeToInterface(performer).setFeeTo(payable(newFeeTo));
    }

    /**
     * @dev See MultiSigInterface - setFeeRateBySigs
     * 
     * Requirements:
     * - ..
     */ 
    function setFeeRateBySigs(
        Signature[] calldata sigs, 
        address performer,
        uint256 newFeeRate, 
        uint256 deadline
    ) external override onlyCommittee {
        
        require(deadline >= block.timestamp, "Committee::setFeeRateBySigs : Signatrue is timeout");

        // genetate struct data hash
        bytes32 typeDataHash = keccak256(abi.encode(TypeSetFeeRateHash, performer, newFeeRate, block.chainid, nonces++, deadline));

        // hash Type data
        bytes32 hashedTypeData = _hashTypedDataV4(typeDataHash);

         _validateSigsByteTypedData(sigs, hashedTypeData);

        FeeToInterface(performer).setFeeRate(newFeeRate);
    }

    /**
     * @dev See MultiSigInterface - checkSetFeeToSigs
     * 
     * Requirements:
     * - ..
     */ 
    function transferContractOwnerBySigs(
        Signature[] calldata sigs, 
        address ownerContract,
        address newOwner, 
        uint256 deadline
    ) external override onlyCommittee {
        
        require(deadline >= block.timestamp, "Committee::transferContractOwnerBySigs : Signatrue is timeout");

        // genetate struct data hash
        bytes32 typeDataHash = keccak256(
            abi.encode(TypeTransferOwnerHash, ownerContract, newOwner, block.chainid, nonces++, deadline)
        );

        // hash Type data
        bytes32 hashedTypeData = _hashTypedDataV4(typeDataHash);

         _validateSigsByteTypedData(sigs, hashedTypeData);

        OwnerInterface(ownerContract).transferOwnership(newOwner);
    }

    /**
     * @dev See MultiSigInterface - functionCallBySigs
     * 
     * Requirements:
     * -
     */ 
    function functionCallBySigs(
        Signature[] calldata sigs, 
        address theContract,
        bytes calldata bytecode, 
        uint256 deadline
    ) external override onlyCommittee {
        require(deadline >= block.timestamp, "Committee::functionCallBySigs : Signatrue is timeout");

        bytecodeValidate(bytecode);
        // genetate struct data hash
        bytes32 typeDataHash = keccak256(
            abi.encode(TypeFunctionCallHash, theContract, keccak256(bytecode), block.chainid, nonces++, deadline)
        );

        // hash Type data
        bytes32 hashedTypeData = _hashTypedDataV4(typeDataHash);

         _validateSigsByteTypedData(sigs, hashedTypeData);

        theContract.functionCall(bytecode);
    }

    /**
     * @dev bytecode validate than some function cant execute by function call
     * 
     * Params
     * - bytes memory data: called bytecode
     * 
     * Requirements
     * - data.length >= 4 
     * - called function selecor not in selectors 
     */ 
    function bytecodeValidate(bytes memory data) internal view {
        // data length must large than 4
        require(data.length >= 4, "Committee::bytecodeValidate : bytecode error");

        bytes4 calledSelector;
        assembly {
            calledSelector := mload(add(data, 32))
        }

        require(
            !selectors[calledSelector], 
            "Committee::bytecodeValidate : function was banned"
        );
    }

    /**
     * @dev check signatrues
     * 
     * Requirements:
     * - sigs number must large minimumSigs
     * - signature address must equal recoverred address
     * - signature address must belongs to commitee
     */ 
    function _validateSigsByteTypedData(
        Signature[] calldata sigs, 
        bytes32 typedDataHash
    ) private {
        initCommitteeMemberStatus();

        uint256 sigsLength = sigs.length;
        uint256 _minumumSigAmount = getMinimumSigs();

        require(
            sigsLength >= _minumumSigAmount, 
            "Committee::_validateSigsByteTypedData : Sigs number must exceed minimum"
        );

        uint256 walletCounter;

        for(uint256 i; i < sigsLength; i++) {
            address recoveredAddress = ECDSAUpgradeable.recover(
                typedDataHash, 
                sigs[i].v, 
                sigs[i].r, 
                sigs[i].s
            );

            require(
                recoveredAddress == sigs[i].signatory, 
                "Committee::_validateSigsByteTypedData: Signatrue address is error"
            );
            require(
                commitee.exists(recoveredAddress), 
                "Committee::_validateSigsByteTypedData : Signature address is not in commitee"
            );

            // do a simple multiaddress check
            if(committeeStatus[recoveredAddress]) {
                walletCounter ++;
                delete committeeStatus[recoveredAddress];
            }
        }
        require(
            walletCounter >= _minumumSigAmount, 
            "Committee::_validateSigsByteTypedData : Signatrues is not enough"
        );
    }


    // run initCommitteeMemberStatus before validate signatrues;
    // make committee address status to be true;
    // for count sigs number
    function initCommitteeMemberStatus() internal {
        uint256 length = commitee.length();
        for(uint256 i; i < length; i ++) {
            CommitteeSet.Member memory member = commitee.at(i);

            // save gas
            if(!committeeStatus[member._wallet]) {
                committeeStatus[member._wallet] = true;
            }
        }

        return;
    }

    /**
     * @dev committee config set sigs validate
     * 
     * Params
     * - Signature[] calldata sigs: committee sigs
     * - uint256 deadline: sig dead line
     */ 
    function commiteeConfigSigValidate(Signature[] calldata sigs, uint256 deadline) internal {
        require(
            deadline >= block.timestamp, 
            "Committee::commiteeConfigSigValidate : Signatrue is timeout"
        );
        // genetate struct data hash
        bytes32 typeDataHash = keccak256(
            abi.encode(TypeCommitteeConfigHash, msg.sig, block.chainid, nonces++, deadline)
        );

        // hash Type data
        bytes32 hashedTypeData = _hashTypedDataV4(typeDataHash);

        _validateSigsByteTypedData(sigs, hashedTypeData);
    }

    /**
     * @dev See MultiSigInterface - addCommiteeMember
     * 
     * Requirements:
     * - new member not in commitee
     * 
     * Notes
     * - 0x31b4197d
     */ 
    function addCommiteeMember(Signature[] calldata sigs, uint256 deadline, address newMemberWallet) external override onlyCommittee {

        require(
            !commitee.exists(newMemberWallet), 
            "Committee::addCommiteeMember : New member already exist in commitee"
        );

        commiteeConfigSigValidate(sigs, deadline);
        
        CommitteeSet.Member memory member = CommitteeSet.Member(newMemberWallet);
        commitee.add(member);

        emit CommiteeMemberChange(newMemberWallet, "add", block.timestamp);
    }

    /**
     * @dev initial selector mapping that functionCall cant run it;
     * 
     * Selectors
     * - SwapInterface.setPerformer
     * - FeeToInterface.setFeeTo
     * - FeeToInterface.setFeeRate
     * - OwnerInterface.transferOwnership
     */ 
    function initSelectorMap() external onlyCommittee {

        selectors[SwapInterface.setPerformer.selector] = true;

        selectors[FeeToInterface.setFeeTo.selector] = true;

        selectors[FeeToInterface.setFeeRate.selector] = true;

        selectors[OwnerInterface.transferOwnership.selector] = true;
    }

    /**
     * @dev See MultiSigInterface - removeCommiteeMember
     * 
     * Requirements:
     * - new member in commitee
     * 
     * Notes
     * - 0x67a88c5b
     */ 
    function removeCommiteeMember(
        Signature[] calldata sigs, 
        uint256 deadline, 
        address memberWallet
    ) external override onlyCommittee {
        require(
            commitee.length() > 1, 
            "Committee::removeCommiteeMember : Members number must large than 1"
        );

        commiteeConfigSigValidate(sigs, deadline);

        CommitteeSet.Member memory member = CommitteeSet.Member(memberWallet);
        require(
            commitee.contains(member), 
            "Committee::removeCommiteeMember : new member not exists in commitee"
        );

        commitee.remove(member);

        emit CommiteeMemberChange(memberWallet, "remove", block.timestamp);
    }

    /**
     * @dev See MultiSigInterface - setMinimumSigs
     * 
     * Requirements:
     * - new sigs number cant equal old
     * 
     * Notes
     * - 0xbfd503a2
     */ 
    function setMinimumSigs(
        Signature[] calldata sigs, 
        uint256 deadline, 
        uint256 newMinimumSigs
    ) external override onlyCommittee {
        require(
            newMinimumSigs >= 1, 
            "Committee::setMinimumSigs : sigs number must large or equal 1"
        );

        commiteeConfigSigValidate(sigs, deadline);

        emit SetMinimumSigs(minimumSigs, newMinimumSigs, block.timestamp);

        minimumSigs = newMinimumSigs;
    }

    /**
     * @dev get minimum sigs
     * if members less than minimum sigs numbers, choose members number
     * 
     * @return uint256
     */ 
    function getMinimumSigs() internal view returns(uint256) {
        uint256 membersNum = commitee.length();
        // find small number
        uint256 number = minimumSigs > membersNum ? membersNum : minimumSigs;

        return number;
    }

    /**
     * @dev upgrade committee contract by committee
     * 
     * Notes
     * - 0x91e2a7b5
     */ 
    function upgradeToBySigs(
        Signature[] calldata sigs, 
        uint256 deadline, 
        address implementation
    ) external override onlyCommittee {
        commiteeConfigSigValidate(sigs, deadline);

        this.upgradeTo(implementation);
    }

    // transfer eth balance to recipient
    function skimETH(
        Signature[] calldata sigs,
        uint256 deadline, 
        address payable recipient
    ) external onlyCommittee {
        commiteeConfigSigValidate(sigs, deadline);
        uint balance = address(this).balance;
        recipient.transfer(balance);
    }

    // transfer erc20 token to recipient
    // token is erc20 token address
    function skimToken(
        Signature[] calldata sigs,
        uint256 deadline, 
        address token,
        address payable recipient
    ) external onlyCommittee {
        commiteeConfigSigValidate(sigs, deadline);
        uint balance = IERC20(token).balanceOf(address(this));
        token.safeTransfer(recipient, balance);
    }

    /// get committee amount
    function commiteeMemberAmount() external view returns(uint256) {
        return commitee.length();
    }

    /// check wallet address is exists in committee
    function isCommitteeMember(address wallet) external view returns(bool) {
        return commitee.exists(wallet);
    }

    /// get committee member by index 
    function getCommitteeMember(uint256 index) external view returns(CommitteeSet.Member memory) {
        return commitee.at(index);
    }

    /// get all committee members
    function getAllMembers() external view returns(CommitteeSet.Member[] memory) {
        return commitee.values();
    }

    /// uups interface
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        view
    {
        require(
            msg.sender == address(this), 
            "Committee::_authorizeUpgrade: upgrade caller error"
        );
    }

}