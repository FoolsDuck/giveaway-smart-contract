// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

abstract contract Maps {
    function indexOfAddress(address[] memory arr, address searchFor)
        public
        pure
        returns (uint256)
    {
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == searchFor) {
                return i;
            }
        }
        revert("Address Not Found");
    }
}
