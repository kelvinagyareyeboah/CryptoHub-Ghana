// SPDX-License-Identifier: GNU
pragma solidity ^0.8.20;

// ============================================================
//  OpenZeppelin Imports
// ============================================================
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title UltraAdvancedERC721Token V2 (Optimized)
 * @author Kelvin
 * @notice Production-grade NFT contract
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
    error IncorrectETH();
    error SaleNotActive();
    error InvalidProof();
    error NoFunds();

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
        uint256 mintPrice_,
        address royaltyReceiver,
        uint96 royaltyFee
    ) ERC721(name_, symbol_) {
        baseURI = baseURI_;
        unrevealedURI = unrevealedURI_;

        maxSupply = maxSupply_;
        maxPerAddress = maxPerAddress_;
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

    // ============================================================
    //  MINT
    // ============================================================
    function mint(uint256 quantity)
        external
        payable
        nonReentrant
        whenNotPaused
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
        supplyCheck(quantity)
    {
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
        if (!revealed) return unrevealedURI;

        return string(
            abi.encodePacked(baseURI, _toString(tokenId), ".json")
        );
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        return Strings.toString(value);
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
        mintPrice = price;
    }

    function setWhitelistRoot(bytes32 root) external onlyOwner {
        whitelistMerkleRoot = root;
    }

    function setRoyalty(address receiver, uint96 fee) external onlyOwner {
        _setDefaultRoyalty(receiver, fee);
    }

    function setMinter(address minter, bool status) external onlyOwner {
        approvedMinters[minter] = status;
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
        uint256 balance = address(this).balance;
        if (balance == 0) revert NoFunds();

        (bool success, ) = to.call{value: balance}("");
        require(success);

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
