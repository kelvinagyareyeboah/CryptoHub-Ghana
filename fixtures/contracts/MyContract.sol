
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
