// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IPool} from "../Interface/IPool.sol";

library Library {
  using SafeMath for uint;

    // fetches and sorts the reserves for a pair
    function getReserves(address pool) internal view returns (uint reserve) {
        uint reserve = IPool(pool).getReserves();
    }
}

