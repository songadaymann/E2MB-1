// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IStaffUtils
/// @notice Interface for generating staff lines and clefs
interface IStaffUtils {
    struct StaffGeometry {
        uint16 canvasWidth;
        uint16 canvasHeight; 
        uint16 staffLeft;       // Left edge of staff lines
        uint16 staffRight;      // Right edge of staff lines
        uint16 trebleTop;       // Top line of treble staff
        uint16 trebleBottom;    // Bottom line of treble staff (trebleTop + 40)
        uint16 bassTop;         // Top line of bass staff
        uint16 bassBottom;      // Bottom line of bass staff (bassTop + 40)
        uint16 lineSpacing;     // Space between staff lines (10px)
    }
    
    /// @notice Get standard large geometry (600x600 canvas)
    /// @return Geometry configuration
    function largeGeometry() external pure returns (StaffGeometry memory);
    
    /// @notice Generate staff lines for both treble and bass
    /// @param geom Staff geometry
    /// @param strokeColor Color for staff lines
    /// @return SVG string with staff lines
    function generateStaffLines(StaffGeometry memory geom, string memory strokeColor) external pure returns (string memory);
    
    /// @notice Generate clefs (treble and bass)
    /// @param geom Staff geometry
    /// @param fillColor Color for clefs
    /// @return SVG string with clef symbols
    function generateClefs(StaffGeometry memory geom, string memory fillColor) external pure returns (string memory);
    
    /// @notice Generate complete grand staff (lines + clefs)
    /// @param geom Staff geometry
    /// @param strokeColor Color for lines
    /// @param fillColor Color for clefs
    /// @return SVG string with complete grand staff
    function generateGrandStaff(StaffGeometry memory geom, string memory strokeColor, string memory fillColor) external view returns (string memory);
}
