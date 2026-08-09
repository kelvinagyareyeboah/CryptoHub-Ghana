// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ============================================================
//  OpenZeppelin Imports
// ============================================================
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title UltraAdvancedERC721Token
 * @author Kelvin
 * @notice Production-grade NFT contract with public/whitelist mint phases,
 *         Merkle-proof allowlisting, ERC2981 royalties, and admin minting.
 *
 * @dev Changes from the previous revision:
 *   - Fixed invalid SPDX identifier ("GNU" is not a recognized SPDX license
 *     ID; set to MIT — change to match your actual license).
 *   - Updated OpenZeppelin import paths: `security/Pausable.sol` and
 *     `security/ReentrancyGuard.sol` were relocated to `utils/` in OZ
 *     v4.9+; the old paths will fail to resolve on current OZ versions.
 *   - Explicitly imported `Strings.sol` instead of relying on it being
 *     re-exported transitively.
 *   - Added zero-quantity and zero-address guards that were previously
 *     missing (e.g. `mint(0)` used to silently succeed and emit a
 *     no-op `Minted` event).
 *   - Added a `maxPerTx` cap, separate from `maxPerAddress`, so a single
 *     call (including `adminMint`) can't mint an amount large enough to
 *     exceed the block gas limit and brick itself.
 *   - Constructor now validates `maxSupply_ > 0`, `maxPerAddress_ > 0`,
 *     `maxPerTx_ > 0`, and `royaltyReceiver != address(0)`.
 *   - Added missing events (`MintPriceUpdated`, `WhitelistRootUpdated`,
 *     `MinterUpdated`, `RoyaltyUpdated`) for full off-chain auditability
 *     of every admin action.
 *   - `withdraw` now validates the recipient is non-zero and surfaces a
 *     custom error instead of a bare `require(success)`.
 *   - Custom errors added: `ZeroQuantity`, `ZeroAddress`, `MaxPerTxExceeded`,
 *     `InvalidConstructorArgs`.
 *   - NatSpec added throughout.
 */
contract UltraAdvancedERC721Token is
    ERC721Enumerable,
    ERC2981,
    Ownable,
    Pausable,
    ReentrancyGuard
{
    // ============================================================
    //  ERRORS (Gas Efficient)
    // ============================================================
    error NotAuthorized();
    error MaxSupplyExceeded();
    error MintLimitExceeded();
    error MaxPerTxExceeded();
    error IncorrectETH();
    error SaleNotActive();
    error InvalidProof();
    error NoFunds();
    error ZeroQuantity();
    error ZeroAddress();
    error InvalidConstructorArgs();
    error WithdrawFailed();

    // ============================================================
    //  ENUMS
    // ============================================================
    enum MintPhase {
        CLOSED,
        WHITELIST,
        PUBLIC
    }

    // ============================================================
    //  STATE
    // ============================================================
    uint256 public totalMinted;
    uint256 public immutable maxSupply;
    uint256 public immutable maxPerAddress;
    uint256 public immutable maxPerTx;

    uint256 public mintPrice;
    bool public revealed;

    string public baseURI;
    string public unrevealedURI;

    MintPhase public currentPhase;

    bytes32 public whitelistMerkleRoot;

    mapping(address => uint256) public minted;
    mapping(address => bool) public approvedMinters;

    // ============================================================
    //  EVENTS
    // ============================================================
    event Minted(address indexed user, uint256 quantity);
    event PhaseChanged(MintPhase phase);
    event BaseURISet(string uri);
    event Revealed();
    event Withdrawn(address indexed to, uint256 amount);
    event MintPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event WhitelistRootUpdated(bytes32 oldRoot, bytes32 newRoot);
    event MinterUpdated(address indexed minter, bool status);
    event RoyaltyUpdated(address indexed receiver, uint96 fee);

    // ============================================================
    //  CONSTRUCTOR
    // ============================================================
    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        string memory unrevealedURI_,
        uint256 maxSupply_,
        uint256 maxPerAddress_,
        uint256 maxPerTx_,
        uint256 mintPrice_,
        address royaltyReceiver,
        uint96 royaltyFee
    ) ERC721(name_, symbol_) {
        if (maxSupply_ == 0 || maxPerAddress_ == 0 || maxPerTx_ == 0) {
            revert InvalidConstructorArgs();
        }
        if (maxPerTx_ > maxPerAddress_) revert InvalidConstructorArgs();
        if (royaltyReceiver == address(0)) revert ZeroAddress();

        baseURI = baseURI_;
        unrevealedURI = unrevealedURI_;

        maxSupply = maxSupply_;
        maxPerAddress = maxPerAddress_;
        maxPerTx = maxPerTx_;
        mintPrice = mintPrice_;

        _setDefaultRoyalty(royaltyReceiver, royaltyFee);
    }

    // ============================================================
    //  MODIFIERS
    // ============================================================
    modifier onlyMinter() {
        if (msg.sender != owner() && !approvedMinters[msg.sender]) {
            revert NotAuthorized();
        }
        _;
    }

    modifier nonZeroQuantity(uint256 quantity) {
        if (quantity == 0) revert ZeroQuantity();
        _;
    }

    modifier supplyCheck(uint256 quantity) {
        if (totalMinted + quantity > maxSupply) {
            revert MaxSupplyExceeded();
        }
        _;
    }

    modifier walletLimit(address user, uint256 quantity) {
        if (minted[user] + quantity > maxPerAddress) {
            revert MintLimitExceeded();
        }
        _;
    }

    modifier txLimit(uint256 quantity) {
        if (quantity > maxPerTx) revert MaxPerTxExceeded();
        _;
    }

    // ============================================================
    //  MINT
    // ============================================================
    function mint(uint256 quantity)
        external
        payable
        nonReentrant
        whenNotPaused
        nonZeroQuantity(quantity)
        txLimit(quantity)
        supplyCheck(quantity)
        walletLimit(msg.sender, quantity)
    {
        if (currentPhase != MintPhase.PUBLIC) revert SaleNotActive();
        if (msg.value != mintPrice * quantity) revert IncorrectETH();

        _mintBatch(msg.sender, quantity);
    }

    function whitelistMint(uint256 quantity, bytes32[] calldata proof)
        external
        payable
        nonReentrant
        whenNotPaused
        nonZeroQuantity(quantity)
        txLimit(quantity)
        supplyCheck(quantity)
        walletLimit(msg.sender, quantity)
    {
        if (currentPhase != MintPhase.WHITELIST) revert SaleNotActive();
        if (!_verify(msg.sender, proof)) revert InvalidProof();
        if (msg.value != mintPrice * quantity) revert IncorrectETH();

        _mintBatch(msg.sender, quantity);
    }

    function adminMint(address to, uint256 quantity)
        external
        onlyMinter
        nonZeroQuantity(quantity)
        txLimit(quantity)
        supplyCheck(quantity)
    {
        if (to == address(0)) revert ZeroAddress();
        _mintBatch(to, quantity);
    }

    // ============================================================
    //  INTERNAL MINT
    // ============================================================
    function _mintBatch(address to, uint256 quantity) internal {
        uint256 start = totalMinted;

        for (uint256 i; i < quantity; ) {
            _safeMint(to, start + i);

            unchecked {
                i++;
            }
        }

        totalMinted += quantity;
        minted[to] += quantity;

        emit Minted(to, quantity);
    }

    // ============================================================
    //  METADATA
    // ============================================================
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        _requireOwned(tokenId);

        if (!revealed) return unrevealedURI;

        return string(
            abi.encodePacked(baseURI, Strings.toString(tokenId), ".json")
        );
    }

    function setBaseURI(string calldata uri) external onlyOwner {
        baseURI = uri;
        emit BaseURISet(uri);
    }

    function reveal() external onlyOwner {
        revealed = true;
        emit Revealed();
    }

    // ============================================================
    //  ADMIN
    // ============================================================
    function setPhase(MintPhase phase) external onlyOwner {
        currentPhase = phase;
        emit PhaseChanged(phase);
    }

    function setMintPrice(uint256 price) external onlyOwner {
        emit MintPriceUpdated(mintPrice, price);
        mintPrice = price;
    }

    function setWhitelistRoot(bytes32 root) external onlyOwner {
        emit WhitelistRootUpdated(whitelistMerkleRoot, root);
        whitelistMerkleRoot = root;
    }

    function setRoyalty(address receiver, uint96 fee) external onlyOwner {
        if (receiver == address(0)) revert ZeroAddress();
        _setDefaultRoyalty(receiver, fee);
        emit RoyaltyUpdated(receiver, fee);
    }

    function setMinter(address minter, bool status) external onlyOwner {
        if (minter == address(0)) revert ZeroAddress();
        approvedMinters[minter] = status;
        emit MinterUpdated(minter, status);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // ============================================================
    //  WITHDRAW
    // ============================================================
    function withdraw(address payable to)
        external
        onlyOwner
        nonReentrant
    {
        if (to == address(0)) revert ZeroAddress();

        uint256 balance = address(this).balance;
        if (balance == 0) revert NoFunds();

        (bool success, ) = to.call{value: balance}("");
        if (!success) revert WithdrawFailed();

        emit Withdrawn(to, balance);
    }

    // ============================================================
    //  WHITELIST
    // ============================================================
    function _verify(address user, bytes32[] calldata proof)
        internal
        view
        returns (bool)
    {
        return
            MerkleProof.verify(
                proof,
                whitelistMerkleRoot,
                keccak256(abi.encodePacked(user))
            );
    }

    // ============================================================
    //  OVERRIDES
    // ============================================================
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Enumerable, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    receive() external payable {}
}

