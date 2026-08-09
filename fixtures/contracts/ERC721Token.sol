
    }

    // ============================================================
    //  WITHDRAW
    // ==================================
    function withdraw(address payable to)
        external
        onlyOwner
        n
        uint256 balance = address(this).balance;
        if (balance == 0) revert NoFunds();

        (bool success, ) = to.call{value: balance}("");
        r

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
