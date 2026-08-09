

        emit Withdrawn(to, balance);
    }

    // ==============================
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
