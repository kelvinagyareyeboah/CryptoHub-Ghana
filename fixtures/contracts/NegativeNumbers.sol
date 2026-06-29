// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title AdvancedNegativeNumbersV3
 * @author Kelvin
 * @notice Optimized, secure, production-ready contract for signed integer operations
 */
contract AdvancedNegativeNumbersV3 {
    // =============================================================
    // STORAGE (OPTIMIZED PACKING)
    // =============================================================

    int256 private _storedNumber;
    int256 private _minValue;
    int256 private _maxValue;

    address public owner;
    address public pendingOwner;

    uint128 public updateCount;
    uint128 public operationCount;

    bool public paused;
    bool public initialized;

    // =============================================================
    // REENTRANCY GUARD
    // =============================================================

    uint256 private _locked;

    modifier nonReentrant() {
        require(_locked == 0, "Reentrancy");
        _locked = 1;
        _;
        _locked = 0;
    }

    // =============================================================
    // ENUMS
    // =============================================================

    enum Operation {
        ADD,
        SUBTRACT,
        MULTIPLY,
        DIVIDE,
        ABS,
        NEGATE,
        POWER,
        MIN,
        MAX
    }

    // =============================================================
    // EVENTS
    // =============================================================

    event NumberUpdated(address indexed executor, int256 oldValue, int256 newValue);
    event OperationExecuted(address indexed executor, Operation op, int256 input, int256 result);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event Paused();
    event Unpaused();
    event Initialized(int256 value);

    // =============================================================
    // ERRORS (CHEAPER THAN STRINGS)
    // =============================================================

    error Unauthorized();
    error PausedError();
    error InvalidRange();
    error OutOfRange();
    error NotInitialized();
    error ZeroAddress();
    error InvalidOperation();
    error DivideByZero();
    error OverflowRisk();

    // =============================================================
    // MODIFIERS
    // =============================================================

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert PausedError();
        _;
    }

    modifier isInitialized() {
        if (!initialized) revert NotInitialized();
        _;
    }

    modifier validRange(int256 value) {
        if (value < _minValue || value > _maxValue) revert OutOfRange();
        _;
    }

    // =============================================================
    // CONSTRUCTOR
    // =============================================================

    constructor() {
        owner = msg.sender;
    }

    // =============================================================
    // INITIALIZATION
    // =============================================================

    function initialize(int256 initialValue, int256 minRange, int256 maxRange)
        external
        onlyOwner
    {
        if (initialized) revert InvalidRange();
        if (minRange >= maxRange) revert InvalidRange();

        _storedNumber = initialValue;
        _minValue = minRange;
        _maxValue = maxRange;
        initialized = true;

        emit Initialized(initialValue);
    }

    // =============================================================
    // CORE INTERNAL EXECUTION (NO EXTERNAL CALLS)
    // =============================================================

    function _execute(Operation op, int256 value) internal returns (int256 result) {
        int256 current = _storedNumber;

        if (op == Operation.ADD) {
            result = current + value;
        } else if (op == Operation.SUBTRACT) {
            result = current - value;
        } else if (op == Operation.MULTIPLY) {
            result = current * value;
        } else if (op == Operation.DIVIDE) {
            if (value == 0) revert DivideByZero();
            result = current / value;
        } else if (op == Operation.ABS) {
            result = current < 0 ? -current : current;
        } else if (op == Operation.NEGATE) {
            result = -current;
        } else if (op == Operation.POWER) {
            if (value < 0 || value > 50) revert OverflowRisk(); // prevent insane exponent
            result = current ** uint256(value);
        } else if (op == Operation.MIN) {
            result = current < value ? current : value;
        } else if (op == Operation.MAX) {
            result = current > value ? current : value;
        } else {
            revert InvalidOperation();
        }

        if (result < _minValue || result > _maxValue) revert OutOfRange();

        _update(result);
    }

    function _update(int256 newValue) internal {
        int256 old = _storedNumber;
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
      
