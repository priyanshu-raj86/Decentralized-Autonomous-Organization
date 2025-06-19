// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralized Autonomous Organization (DAO)
 * @dev A simple DAO contract with proposal creation, voting, and execution functionality
 * @author DAO Development Team
 */
contract Project {

    // Struct to represent a proposal
    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 deadline;
        bool executed;
        bool active;
        mapping(address => bool) hasVoted;
        mapping(address => bool) vote; // true = for, false = against
    }

    // State variables
    mapping(uint256 => Proposal) private proposalsInternal;
    mapping(address => uint256) public memberTokens;
    mapping(address => bool) public isMember;

    uint256 public proposalCount;
    uint256 public totalTokens;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MIN_TOKENS_TO_PROPOSE = 100;
    uint256 public constant MIN_TOKENS_TO_VOTE = 1;

    address public admin;

    // Events
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string title);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 tokens);
    event ProposalExecuted(uint256 indexed proposalId, bool success);
    event MemberAdded(address indexed member, uint256 tokens);

    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    modifier onlyMember() {
        require(isMember[msg.sender], "Only members can call this function");
        _;
    }

    modifier validProposal(uint256 _proposalId) {
        require(_proposalId < proposalCount, "Invalid proposal ID");
        Proposal storage proposal = proposalsInternal[_proposalId];
        require(proposal.active, "Proposal is not active");
        require(block.timestamp <= proposal.deadline, "Voting period has ended");
        _;
    }

    constructor() {
        admin = msg.sender;
        isMember[admin] = true;
        memberTokens[admin] = 1000;
        totalTokens = 1000;
        emit MemberAdded(admin, 1000);
    }

    function createProposal(string memory _title, string memory _description) external onlyMember {
        require(memberTokens[msg.sender] >= MIN_TOKENS_TO_PROPOSE, "Insufficient tokens to create proposal");
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");

        uint256 proposalId = proposalCount;
        Proposal storage newProposal = proposalsInternal[proposalId];

        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.title = _title;
        newProposal.description = _description;
        newProposal.deadline = block.timestamp + VOTING_PERIOD;
        newProposal.executed = false;
        newProposal.active = true;
        newProposal.forVotes = 0;
        newProposal.againstVotes = 0;

        proposalCount++;

        emit ProposalCreated(proposalId, msg.sender, _title);
    }

    function vote(uint256 _proposalId, bool _support) external onlyMember validProposal(_proposalId) {
        require(memberTokens[msg.sender] >= MIN_TOKENS_TO_VOTE, "Insufficient tokens to vote");

        Proposal storage proposal = proposalsInternal[_proposalId];
        require(!proposal.hasVoted[msg.sender], "Already voted on this proposal");

        uint256 voterTokens = memberTokens[msg.sender];
        proposal.hasVoted[msg.sender] = true;
        proposal.vote[msg.sender] = _support;

        if (_support) {
            proposal.forVotes += voterTokens;
        } else {
            proposal.againstVotes += voterTokens;
        }

        emit VoteCast(_proposalId, msg.sender, _support, voterTokens);
    }

    function executeProposal(uint256 _proposalId) external {
        require(_proposalId < proposalCount, "Invalid proposal ID");

        Proposal storage proposal = proposalsInternal[_proposalId];
        require(proposal.active, "Proposal is not active");
        require(block.timestamp > proposal.deadline, "Voting period is still active");
        require(!proposal.executed, "Proposal already executed");

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        uint256 quorum = totalTokens / 4;

        bool passed = (totalVotes >= quorum) && (proposal.forVotes > proposal.againstVotes);

        proposal.executed = true;
        proposal.active = false;

        emit ProposalExecuted(_proposalId, passed);
    }

    function addMember(address _member, uint256 _tokens) external onlyAdmin {
        require(_member != address(0), "Invalid member address");
        require(_tokens > 0, "Tokens must be greater than 0");
        require(!isMember[_member], "Address is already a member");

        isMember[_member] = true;
        memberTokens[_member] = _tokens;
        totalTokens += _tokens;

        emit MemberAdded(_member, _tokens);
    }

    function getProposal(uint256 _proposalId) external view returns (
        uint256 id,
        address proposer,
        string memory title,
        string memory description,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 deadline,
        bool executed,
        bool active
    ) {
        require(_proposalId < proposalCount, "Invalid proposal ID");

        Proposal storage proposal = proposalsInternal[_proposalId];
        return (
            proposal.id,
            proposal.proposer,
            proposal.title,
            proposal.description,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.deadline,
            proposal.executed,
            proposal.active
        );
    }

    function getVote(uint256 _proposalId, address _voter) external view returns (bool hasVoted, bool voteValue) {
        require(_proposalId < proposalCount, "Invalid proposal ID");

        Proposal storage proposal = proposalsInternal[_proposalId];
        return (proposal.hasVoted[_voter], proposal.vote[_voter]);
    }

    function getMemberInfo(address _member) external view returns (bool, uint256) {
        return (isMember[_member], memberTokens[_member]);
    }
}

