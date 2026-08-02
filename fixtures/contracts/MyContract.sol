returns (uint256) {
        return history.length;
    }

    function getHistory(uint256 offset, uint256 limit) external view returns (HistoryEntry[] memory) {
        uint256 end = offset + limit;
        if (end > history.length) {
            end = history.length;
        }

        HistoryEntry[] memory page = new HistoryEntry[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            page[i - offset] = history[i];
        }
        return page;
    }

    function getSystemStatus() external view returns (
        bool isPaused,
        bool isEmergency,
        uint256 updates,
        uint256 adminsCount,
        uint256 lastChange
    ) {
        return (paused, emergencyMode, totalUpdates, totalAdminsAdded, lastUpdated);
    }

    // Write Functions
    function setAttribute(string memory newValue) 
        external 
        onlyAdminOrOwner 
        whenNotPaused 
        whenNotLocked 
        noEmergency 
        rateLimited 
    {
        require(bytes(newValue).length > 0, "Empty string");
        
        string memory oldValue = _attribute;
        _setAttribute(newValue);
        _addHistoryEntry(newValue, msg.sender);
        
        emit AttributeUpdated(msg.sender, oldValue, newValue, block.timestamp);
    }

    // Pause & Lock Controls
    function pause() external onlyOwner {
        paused = true;
        emit ContractPaused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit ContractUnpaused(msg.sender);
    }

    function lockAttribute(uint256 duration) external onlyOwner {
        require(duration <= MAX_LOCK_DURATION, "Duration too long");
        lockUntil = block.timestamp + duration;
        emit AttributeLockedEvent(lockUntil);
    }

    function unlockAttribute() external onlyOwner {
        lockUntil = 0;
        emit AttributeUnlockedEvent();
    }

    function enableEmergencyMode() external onlyOwner emergencyCooldown {
        emergencyMode = true;
        lastEmergencyAction = block.timestamp;
        emit EmergencyModeEnabled(msg.sender);
    }

    function disableEmergencyMode() external onlyOwner emergencyCooldown {
        emergencyMode = false;
        lastEmergencyAction = block.timestamp;
        emit EmergencyModeDisabled(msg.sender);
    }

    // Admin Governance
    function proposeAdmin(address admin) external onlyAdminOrOwner {
        require(admin != address(0), "Invalid address");
        
        adminProposals.push(
            AdminProposal({
                proposedAdmin: admin,
                proposer: msg.sender,
                timestamp: block.timestamp,
                approved: false,
                executed: false
            })
        );
        
        emit AdminProposalCreated(adminProposals.length - 1, admin);
    }

    function approveAdminProposal(uint256 id) external onlyOwner {
        require(id < adminProposals.length, "Invalid proposal ID");
        AdminProposal storage proposal = adminProposals[id];
        require(!proposal.approved, "Already approved");
        require(!proposal.executed, "Already executed");
        
        proposal.approved = true;
        emit AdminProposalApproved(id);
    }

    function executeAdminProposal(uint256 id) external onlyOwner {
        require(id < adminProposals.length, "Invalid proposal ID");
        AdminProposal storage proposal = adminProposals[id];
        require(proposal.approved, "Not approved");
        require(!proposal.executed, "Already executed");
        
        admins[proposal.proposedAdmin] = true;
        totalAdminsAdded++;
        proposal.executed = true;
        
        emit AdminAdded(proposal.proposedAdmin);
        emit AdminProposalExecuted(id);
    }

    function removeAdmin(address admin) external onlyOwner {
        require(admin != address(0), "Invalid address");
        require(admins[admin], "Not an admin");
        
        admins[admin] = false;
        emit AdminRemoved(admin);
    }

    // Ownership
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    // Fallbacks
    receive() external payable {}
    fallback() external payable {}
}
