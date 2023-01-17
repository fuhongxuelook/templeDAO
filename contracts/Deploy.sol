// SPDX-License-Identifier: GPL-3.0

import {SaviProxy} from "./SaviProxy.sol";
import {Performer} from "./Performer.sol";
import {Swap} from "./Swap.sol";

pragma solidity ^0.8.0;

interface OwnerInterface {
    function transferOwnership(address newOwner) external;
}

contract Deploy {

    address public performer;
    address public swap;
    address public proxy;
    address public predicted;

    event SAVI(address _performer, address _proxy);
    event SaviPerform(address _performer);
    event SaviSwap(address _swap);

    function createSaviSalted(bytes32 salt, address owner) external {
        bytes memory data = abi.encodeWithSignature("initialize(address)", performer);
        SaviProxy sp = new SaviProxy{salt: salt}(swap, data);

        proxy = address(sp);

        emit SAVI(performer, proxy);

        OwnerInterface(proxy).transferOwnership(owner);

    }

    function createSwapSalted(bytes32 salt) external {
        Swap s = new Swap{salt: salt}();
        swap = address(s); 

        emit SaviPerform(swap);
    }


    function createPerformSalted(bytes32 salt, address feeTo, address owner) external {
        Performer p = new Performer{salt: salt}(feeTo);
        performer = address(p);

        emit SaviPerform(performer);

        p.transferOwnership(owner);
    }

    function predictedAddress(bytes32 salt) external view returns(address) {
        bytes memory data = abi.encodeWithSignature("initialize(address)", performer);

        address addr = address(uint160(uint(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            salt,
            keccak256(abi.encodePacked(
                type(SaviProxy).creationCode,
                abi.encode(address(swap), data)
            ))
        )))));

        return addr;

    }

    function transferOwner(address deployed, address newOwner) external {
        OwnerInterface(deployed).transferOwnership(newOwner);
    }

    function destruct() external {
        selfdestruct(payable(msg.sender));
    }

    function generateSalt(string memory data) external pure returns(bytes32) {
        return keccak256(bytes(data));
    }
}