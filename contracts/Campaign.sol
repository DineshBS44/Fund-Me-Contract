//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract CampaignFactory {
    address[] public deployedCampaigns;

    event CampaignCreated(address indexed campaign);
    
    function createCampaign(uint minimum) public {
        address newCampaign = address(new Campaign(minimum, msg.sender));
        deployedCampaigns.push(newCampaign);
        emit CampaignCreated(newCampaign);
    }
    
    function getDeployedCampaigns() public view returns (address[] memory) {
        return deployedCampaigns;
    }
}

contract Campaign {
    struct Request {
        string description;
        uint value;
        address recipient;
        bool complete;
        uint approvalCount;
        mapping(address => bool) approvals;
    }

    event RequestCreated(uint indexed requestId, string description, uint value, address recipient);
    event RequestApproved(uint indexed requestId, address indexed approver);
    event RequestVotingFulfilled(uint indexed requestId);
    event ContributedAmount(uint indexed amount);

    address public manager;
    uint public minimumContribution;
    mapping(address => uint) public contributors;
    uint public contributorsCount;
    
    uint numRequests;
    mapping (uint => Request) public requests;
    
    constructor(uint minimum, address creator) {
        manager = creator;
        minimumContribution = minimum;
        contributorsCount = 0;
    }
    
    function contribute() public payable {
        require(msg.value > minimumContribution);
        if(contributors[msg.sender] == 0) {
            contributorsCount++;
        }
        contributors[msg.sender] += msg.value;
        emit ContributedAmount(msg.value);
    }
    
    function createRequest(string memory description, uint value, address recipient) public restricted {
        Request storage r = requests[numRequests++];
        r.description = description;
        r.value = value;
        r.recipient = recipient;
        r.complete = false;
        r.approvalCount = 0;
        emit RequestCreated(numRequests - 1, description, value, recipient);
}
    
    function approveRequest(uint index) public {
        Request storage request = requests[index];
        
        require(contributors[msg.sender] > 0, "You are not a contributor");
        require(!request.approvals[msg.sender]);
        
        request.approvals[msg.sender] = true;
        request.approvalCount++;

        if(request.approvalCount > (contributorsCount / 2)) {
            emit RequestVotingFulfilled(index);
        } else {
            emit RequestApproved(index, msg.sender);
        }
    }
    
    function finalizeRequest(uint index) public restricted {
        Request storage request = requests[index];
        
        require(request.approvalCount > (contributorsCount / 2));
        require(!request.complete);
        
        payable(request.recipient).transfer(request.value);
        request.complete = true;
    }
    
    modifier restricted() {
        require(msg.sender == manager);
        _;
    }

    function getSummary() public view returns (
        uint, uint, uint, uint, address
        ) {
        return (
            minimumContribution,
            address(this).balance,
            numRequests,
            contributorsCount,
            manager
        );
    }

    function getRequestsCount() public view returns (uint) {
        return numRequests;
    }
}