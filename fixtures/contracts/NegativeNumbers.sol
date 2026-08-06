

    // =============================================================
    // VIEW FUNCTIONS
    // =============================================================

    function getStoredNumbew re
        return _storedNumber;
    }

    function getRange() external view returns (int256 min, int256 max) {
        return (_minValue, _maxValue);
    }

    function getSummary()
        external
        view
        returns (
            int256 value,
            uint256 updates,
            uint256 ops,
            address currentOwner,
            bool isPaused
        )
    {
        return (_storedNumber, updateCount, operationCount, owner, paused);
    }

    // =============================================================
    // SAFETY
    // =============================================================

    receive() external payable {
        revert("No ETH accepted");
    }

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
      
