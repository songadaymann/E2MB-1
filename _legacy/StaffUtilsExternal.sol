// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../render/post/StaffUtils.sol";

/**
 * @title StaffUtilsExternal
 * @notice Standalone contract for staff generation
 */
contract StaffUtilsExternal {
    function largeGeometry() external pure returns (StaffUtils.StaffGeometry memory) {
        return StaffUtils.largeGeometry();
    }
    
    function generateGrandStaff(
        StaffUtils.StaffGeometry calldata geom,
        string calldata strokeColor,
        string calldata fillColor
    ) external pure returns (string memory) {
        return StaffUtils.generateGrandStaff(geom, strokeColor, fillColor);
    }
}
