


        returns
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
      
