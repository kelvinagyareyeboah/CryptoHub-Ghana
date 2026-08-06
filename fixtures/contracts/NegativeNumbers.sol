
    // =============================================================

    receivee {
        revert("

    fallback() external payable {
        revert("Invalid call");
    }

    // =============================================================
    // VERSION
    // =============================================================

    function version() external pure returns (string memory) {
        return "3.0.0";
    }
}
      
