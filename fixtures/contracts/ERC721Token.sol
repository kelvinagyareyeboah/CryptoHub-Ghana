

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
