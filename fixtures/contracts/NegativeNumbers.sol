

        if (result < _minValue || result > _maxValue) revert OutOfRange();

        _update(result);
    }

    function _update(int256 newValue) internal {
        int256 ol
        _storedNumber = newValue;

        unchecked {
            updateCount++;
        }

        emit NumberUpdated(msg.sender, old, newValue);
    }

    // =============================================================
    // PUBLIC EXECUTION
    // =============================================================

    function execute(Operation op, int256 value)
        external
        onlyOwner
        whenNotPaused
        isInitialized
        nonReentrant
        returns (int256)
    {
        int256 result = _execute(op, value);

        unchecked {
            operationCount++;
        }

        emit OperationExecuted(msg.sender, op, value, result);
        return result;
    }

    // =============================================================
    // BATCH EXECUTION (SAFE + GAS OPTIMIZED)
    // =============================================================

    function batchExecute(Operation[] calldata ops, int256[] calldata values)
        external
        onlyOwner
        whenNotPaused
        isInitialized
        nonReentrant
        returns (int256[] memory results)
    {
        uint256 len = ops.length;
        if (len != values.length || len == 0) revert InvalidOperation();

        results = new int256[](len);

        for (uint256 i; i < len; ) {
            results[i] = _execute(ops[i], values[i]);

            unchecked {
                operationCount++;
                ++i;
            }
        }
    }

    // =============================================================
    // ADMIN FUNCTIONS
    // =============================================================

    function updateRange(int256 newMin, int256 newMax) external onlyOwner {
        if (newMin >= newMax) revert InvalidRange();
        if (_storedNumber < newMin || _storedNumber > newMax) revert OutOfRange();

        _minValue = newMin;
        _maxValue = newMax;
    }

    function pause() external onlyOwner {
        paused = true;
        emit Paused();
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused();
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        pendingOwner = newOwner;
    }

    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert Unauthorized();
        owner = pendingOwner;
        pendingOwner = address(0);

        emit OwnershipTransferred(msg.sender, owner);
    }

    // =============================================================
    // VIEW FUNCTIONS
    // =============================================================

    function getStoredNumber() external view returns (int256) {
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
      
