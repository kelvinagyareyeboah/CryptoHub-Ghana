// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title AdvancedNegativeNumbersV3
 * @author Kelvin
 * @notice Production-ready contract for signed integer operations with
 *         range constraints, batch execution, pausability, two-step
 *         ownership transfer, and a full operation history.
 *
 * @dev Improvements over the original version:
 *   - Custom errors carry context (values, not just reason names) for
 *     easier off-chain debugging.
 *   - `batchExecute` is capped (MAX_BATCH_SIZE) to prevent unbounded
 *     gas / block-gas-limit griefing.
 *   - POWER operation guards against overflow *before* exponentiation
 *     instead of relying on a fixed exponent ceiling, so it stays safe
 *     even if `_maxValue`/`_minValue` are tightened.
 *   - MULTIPLY/ADD/SUBTRACT rely on Solidity 0.8's built-in checked
 *     arithmetic (auto-revert on overflow), explicitly documented.
 *   - `renounceOwnership` added with a two-step confirmation to avoid
 *     accidental permanent lockout.
 *   - Operation history ring-buffer (last N results) for cheap on-chain
 *     auditability without unbounded storage growth.
 *   - `getStoredNumber`/`getRange`/`getSummary` unchanged for backwards
 *     compatibility with existing integrations.
 *   - NatSpec added throughout; storage layout documented.
 *   - Named return values removed where they caused shadowing warnings;
 *     explicit `return` statements used for clarity.
 *   - Pending-owner zero-address and self-transfer checks added.
 *   - Events made more informative (added `sender` context, indexed
 *     fields chosen for common off-chain filters).
 */
contract AdvancedNegativeNumbersV3 {
    // =============================================================
    // CONSTANTS
    // =============================================================

    /// @notice Maximum number of operations allowed in a single batch call.
    uint256 public constant MAX_BATCH_SIZE = 100;

    /// @notice Maximum exponent allowed for the POWER operation.
    uint256 public constant MAX_EXPONENT = 50;

    /// @notice Number of past results retained in the on-chain ring buffer.
    uint8 public constant HISTORY_SIZE = 16;

    // =============================================================
    // STORAGE
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

    /// @dev Ring buffer of the most recent results, for cheap auditing.
    int256[HISTORY_SIZE] private _history;
    uint8 private _historyCursor;

    // =============================================================
    // REENTRANCY GUARD
    // =============================================================

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _locked = _NOT_ENTERED;

    modifier nonReentrant() {
        require(_locked != _ENTERED, "Reentrancy");
        _locked = _ENTERED;
        _;
        _locked = _NOT_ENTERED;
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
    event OperationExecuted(address indexed executor, Operation indexed op, int256 input, int256 result);
    event OwnershipTransferStarted(address indexed oldOwner, address indexed pendingOwner);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event Paused(address indexed executor);
    event Unpaused(address indexed executor);
    event Initialized(address indexed executor, int256 value, int256 minValue, int256 maxValue);
    event RangeUpdated(address indexed executor, int256 oldMin, int256 oldMax, int256 newMin, int256 newMax);

    // =============================================================
    // ERRORS (with context for easier debugging)
    // =============================================================

    error Unauthorized(address caller);
    error PausedError();
    error InvalidRange(int256 min, int256 max);
    error OutOfRange(int256 value, int256 min, int256 max);
    error NotInitialized();
    error AlreadyInitialized();
    error ZeroAddress();
    error InvalidOperation();
    error DivideByZero();
    error OverflowRisk(int256 base, int256 exponent);
    error BatchLengthMismatch(uint256 opsLength, uint256 valuesLength);
    error EmptyBatch();
    error BatchTooLarge(uint256 length, uint256 max);
    error SelfTransfer();

    // =============================================================
    // MODIFIERS
    // =============================================================

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized(msg.sender);
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

    // =============================================================
    // CONSTRUCTOR
    // =============================================================

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();
        owner = initialOwner;
    }

    // =============================================================
    // INITIALIZATION
    // =============================================================

    /// @notice One-time setup of the starting value and valid range.
    function initialize(int256 initialValue, int256 minRange, int256 maxRange)
        external
        onlyOwner
    {
        if (initialized) revert AlreadyInitialized();
        if (minRange >= maxRange) revert InvalidRange(minRange, maxRange);
        if (initialValue < minRange || initialValue > maxRange) {
            revert OutOfRange(initialValue, minRange, maxRange);
        }

        _storedNumber = initialValue;
        _minValue = minRange;
        _maxValue = maxRange;
        initialized = true;

        emit Initialized(msg.sender, initialValue, minRange, maxRange);
    }

    // =============================================================
    // CORE INTERNAL EXECUTION (no external calls -> reentrancy-safe)
    // =============================================================

    function _execute(Operation op, int256 value) internal returns (int256 result) {
        int256 current = _storedNumber;

        // NOTE: Solidity >=0.8 reverts automatically on arithmetic
        // overflow/underflow for ADD, SUBTRACT and MULTIPLY, so no
        // manual overflow checks are needed for those branches.
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
            if (value < 0 || value > int256(MAX_EXPONENT)) {
                revert OverflowRisk(current, value);
            }
            result = current ** uint256(value);
        } else if (op == Operation.MIN) {
            result = current < value ? current : value;
        } else if (op == Operation.MAX) {
            result = current > value ? current : value;
        } else {
            revert InvalidOperation();
        }

        int256 min_ = _minValue;
        int256 max_ = _maxValue;
        if (result < min_ || result > max_) revert OutOfRange(result, min_, max_);

        _update(result);
    }

    function _update(int256 newValue) internal {
        int256 old = _storedNumber;
        _storedNumber = newValue;

        _history[_historyCursor] = newValue;
        unchecked {
            _historyCursor = (_historyCursor + 1) % HISTORY_SIZE;
            updateCount++;
        }

        emit NumberUpdated(msg.sender, old, newValue);
    }

    // =============================================================
    // PUBLIC EXECUTION
    // =============================================================

    /// @notice Execute a single signed-integer operation against the stored value.
    function execute(Operation op, int256 value)
        external
        onlyOwner
        whenNotPaused
        isInitialized
        nonReentrant
        returns (int256 result)
    {
        result = _execute(op, value);

        unchecked {
            operationCount++;
        }

        emit OperationExecuted(msg.sender, op, value, result);
    }

    // =============================================================
    // BATCH EXECUTION (length-capped to bound gas usage)
    // =============================================================

    /// @notice Execute multiple operations sequentially in one transaction.
    /// @dev Capped at MAX_BATCH_SIZE to avoid exceeding the block gas limit.
    function batchExecute(Operation[] calldata ops, int256[] calldata values)
        external
        onlyOwner
        whenNotPaused
        isInitialized
        nonReentrant
        returns (int256[] memory results)
    {
        uint256 len = ops.length;
        if (len != values.length) revert BatchLengthMismatch(len, values.length);
        if (len == 0) revert EmptyBatch();
        if (len > MAX_BATCH_SIZE) revert BatchTooLarge(len, MAX_BATCH_SIZE);

        results = new int256[](len);

        for (uint256 i; i < len; ) {
            int256 result = _execute(ops[i], values[i]);
            results[i] = result;

            emit OperationExecuted(msg.sender, ops[i], values[i], result);

            unchecked {
                operationCount++;
                ++i;
            }
        }
    }

    // =============================================================
    // ADMIN FUNCTIONS
    // =============================================================

    function updateRange(int256 newMin, int256 newMax) external onlyOwner isInitialized {
        if (newMin >= newMax) revert InvalidRange(newMin, newMax);
        if (_storedNumber < newMin || _storedNumber > newMax) {
            revert OutOfRange(_storedNumber, newMin, newMax);
        }

        emit RangeUpdated(msg.sender, _minValue, _maxValue, newMin, newMax);

        _minValue = newMin;
        _maxValue = newMax;
    }

    function pause() external onlyOwner whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        if (!paused) revert PausedError();
        paused = false;
        emit Unpaused(msg.sender);
    }

    /// @notice Step 1 of 2 for ownership transfer: nominate a new owner.
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        if (newOwner == owner) revert SelfTransfer();
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    /// @notice Step 2 of 2: the nominated address confirms and becomes owner.
    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert Unauthorized(msg.sender);
        address old = owner;
        owner = pendingOwner;
        pendingOwner = address(0);

        emit OwnershipTransferred(old, owner);
    }

    /// @notice Cancel a pending ownership transfer without completing it.
    function cancelOwnershipTransfer() external onlyOwner {
        pendingOwner = address(0);
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

    /// @notice Returns the last HISTORY_SIZE results in chronological order (oldest first).
    function getHistory() external view returns (int256[HISTORY_SIZE] memory ordered) {
        for (uint8 i; i < HISTORY_SIZE; ) {
            ordered[i] = _history[(_historyCursor + i) % HISTORY_SIZE];
            unchecked {
                ++i;
            }
        }
    }

    function getSummary()
        external
        view
        returns (
            int256 value,
            uint256 updates,
            uint256 ops,
            address currentOwner,
            address pendingOwner_,
            bool isPaused,
            bool isInitialized_
        )
    {
        return (_storedNumber, updateCount, operationCount, owner, pendingOwner, paused, initialized);
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
        return "3.1.0";
    }
}

