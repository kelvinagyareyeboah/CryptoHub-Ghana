(uint256 tokenId)
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
