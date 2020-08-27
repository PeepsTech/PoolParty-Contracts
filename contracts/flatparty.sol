
// File: browser/oz/ReentrancyGuard.sol

pragma solidity ^0.5.17;

contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor () internal {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "reentrant call");

        _status = _ENTERED;
        
        _;
        
        _status = _NOT_ENTERED;
    }
}
// File: browser/oz/IERC20.sol

pragma solidity ^0.5.17;

interface IERC20 { // brief interface for moloch erc20 token txs
    function balanceOf(address who) external view returns (uint256);
    
    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);
    
    function approve(address spender, uint256 amount) external returns (bool);
}


// File: browser/oz/SafeMath.sol

pragma solidity ^0.5.17;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }
    
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }
    
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0);
        uint256 c = a / b;

        return c;
    }
}
// File: browser/PoolParty.sol

pragma solidity 0.5.17;




interface IIdleToken {
  function token() external returns (address underlying);
  function userAvgPrices(address) external returns (uint256 avgPrice);
  function mintIdleToken(uint256 _amount, bool _skipWholeRebalance) external returns (uint256 mintedTokens);
  function redeemIdleToken(uint256 _amount, bool _skipRebalance, uint256[] calldata _clientProtocolAmounts) external returns (uint256 redeemedTokens);
  function redeemInterestBearingTokens(uint256 _amount) external;
  function rebalance() external returns (bool);
  function rebalanceWithGST() external returns (bool);
  function openRebalance(uint256[] calldata _newAllocations) external returns (bool, uint256 avgApr);
  function tokenPrice() external view returns (uint256 price);
  function getAPRs() external view returns (address[] memory addresses, uint256[] memory aprs);
  function getAvgAPR() external view returns (uint256 avgApr);
  function getCurrentAllocations() external view returns (address[] memory tokenAddresses, uint256[] memory amounts, uint256 total);
}


contract Party is ReentrancyGuard {
    using SafeMath for uint256;
    
    IIdleToken public idleToken;
    
    /****************
    GOVERNANCE PARAMS
    ****************/
    uint256 public periodDuration; // default = 17280 = 4.8 hours in seconds (5 periods per day)
    uint256 public votingPeriodLength; // default = 35 periods (7 days)
    uint256 public gracePeriodLength; // default = 35 periods (7 days)
    uint256 public proposalDepositReward; // default = 10 ETH (~$1,000 worth of ETH at contract deployment)
    uint256 public depositRate; // rate to convert into shares during summoning time (default = 10000000000000000000 wei amt. // 100 wETH => 10 shares)
    uint256 public summoningTime; // needed to determine the current period
    uint256 public partyGoal; // savings goal for DAO 

    address public daoFee; // address where fees are sent
    address public depositToken; // deposit token contract reference; default = periodDuration
    address public minion; // contract that allows execution of arbitrary calls voted on by members // gov. param adjustments
    bytes32 public name; 
    bytes32 public desc;


    // HARD-CODED LIMITS
    // These numbers are quite arbitrary; they are small enough to avoid overflows when doing calculations
    // with periods or shares, yet big enough to not limit reasonable use cases.
    uint256 constant dilutionBound = 3; // default = 3 
    uint256 constant MAX_INPUT = 10**36; // maximum bound for reasonable limits
    uint256 constant MAX_TOKEN_WHITELIST_COUNT = 100; // maximum number of whitelisted tokens

    // ***************
    // EVENTS
    // ***************
    event SummonComplete(address[] indexed summoners, address[] tokens, uint256 summoningTime, uint256 periodDuration, uint256 votingPeriodLength, uint256 gracePeriodLength, uint256 proposalDepositReward, uint256 partyGoal, uint256 depositRate);
    event MakeDeposit(address indexed memberAddress, uint256 indexed tribute, uint256 indexed shares);
    event MakePayment(address indexed sender, address indexed paymentToken, uint256 indexed payment);
    event AmendGovernance(address indexed newToken, address indexed minion, uint256 depositRate);
    event SubmitProposal(address indexed applicant, uint256 sharesRequested, uint256 lootRequested, uint256 tributeOffered, address tributeToken, uint256 paymentRequested, address paymentToken, bytes32 details, bool[7] flags, uint256 proposalId, address indexed memberAddress);
    event SponsorProposal(address sponsor, uint256 proposalId, uint256 proposalIndex, uint256 startingPeriod);
    event SubmitVote(uint256 proposalId, uint256 indexed proposalIndex, address indexed delegateKey, address indexed memberAddress, uint8 uintVote);
    event ProcessProposal(uint256 indexed proposalIndex, bool didPass);
    event ProcessGuildKickProposal(uint256 indexed proposalIndex, uint256 indexed proposalId, bool didPass);
    event Ragequit(address indexed memberAddress, uint256 sharesToBurn, uint256 lootToBurn);
    event TokensCollected(address indexed token, uint256 amountToCollect);
    event CancelProposal(uint256 indexed proposalId, address applicantAddress);
    event Withdraw(address indexed memberAddress, address token, uint256 amount);

    // *******************
    // INTERNAL ACCOUNTING
    // *******************
    uint8 private status;
    uint8 private NOT_SET;
    uint8 private constant SET = 1; // tracks contract summoning set
    uint256 public proposalCount; // total proposals submitted
    uint256 public totalShares; // total shares across all members
    uint256 public totalLoot; // total loot across all members
    uint256 public totalGuildBankTokens; // total tokens with non-zero balance in guild bank

    address public constant GUILD = address(0xdead);
    address public constant ESCROW = address(0xbeef);
    address public constant TOTAL = address(0xbabe);
    mapping(address => mapping(address => uint256)) public userTokenBalances; // userTokenBalances[userAddress][tokenAddress]

    enum Vote {
        Null, // default value, counted as abstention
        Yes,
        No
    }

    struct Member {
        address delegateKey; // the key responsible for submitting proposals and voting - defaults to member address unless updated
        uint256 shares; // the # of voting shares assigned to this member
        uint256 loot; // the loot amount available to this member (combined with shares on ragequit)
        uint256 iTokenAmts;
        uint256 iTokenRedemptions; //interest withdrawn 
        uint256 highestIndexYesVote; // highest proposal index # on which the member voted YES
        bool jailed; // set to proposalIndex of a passing guild kick proposal for this member, prevents voting on and sponsoring proposals
        bool exists; // always true once a member has been created
    }

    struct Proposal {
        address applicant; // the applicant who wishes to become a member - this key will be used for withdrawals (doubles as guild kick target for gkick proposals)
        address proposer; // the account that submitted the proposal (can be non-member)
        address sponsor; // the member that sponsored the proposal (moving it into the queue)
        uint256 sharesRequested; // the # of shares the applicant is requesting
        uint256 lootRequested; // the amount of loot the applicant is requesting
        uint256 tributeOffered; // amount of tokens offered as tribute
        address tributeToken; // tribute token contract reference
        uint256 paymentRequested; // amount of tokens requested as payment
        address paymentToken; // payment token contract reference
        uint256 startingPeriod; // the period in which voting can start for this proposal
        uint256 yesVotes; // the total number of YES votes for this proposal
        uint256 noVotes; // the total number of NO votes for this proposal
        bool[7] flags; // [sponsored, processed, didPass, cancelled, guildkick, spending, member]
        bytes32 details; // proposal details to add context for members 
        uint256 maxTotalSharesAndLootAtYesVote; // the maximum # of total shares encountered at a yes vote on this proposal
        mapping(address => Vote) votesByMember; // the votes on this proposal by each member
    }

    mapping(address => bool) public tokenWhitelist;
    address[] public approvedTokens;

    mapping(address => bool) public proposedToKick;

    mapping(address => Member) public members;
    address[] public memberList;

    mapping(uint256 => Proposal) public proposals;
    uint256[] public proposalQueue;
    
    /******************
    SUMMONING FUNCTIONS
    ******************/
    constructor(
        address[] memory _founders,
        address[] memory _approvedTokens,
        address _daoFee,
        uint256 _periodDuration,
        uint256 _votingPeriodLength,
        uint256 _gracePeriodLength,
        uint256 _proposalDepositReward,
        uint256 _depositRate,
        uint256 _partyGoal,
        bytes32 _name,
        bytes32 _desc
    ) public {
        require(_periodDuration > 0, "_periodDuration zeroed");
        require(_votingPeriodLength > 0, "_votingPeriodLength zeroed");
        require(_votingPeriodLength <= MAX_INPUT, "_votingPeriodLength maxed");
        require(_gracePeriodLength <= MAX_INPUT, "_gracePeriodLength maxed");
        require(_approvedTokens.length > 0, "need token");
        
        depositToken = _approvedTokens[0];
        // NOTE: move event up here, avoid stack too deep if too many approved tokens
        emit SummonComplete(_founders, _approvedTokens, now, _periodDuration, _votingPeriodLength, _gracePeriodLength, _proposalDepositReward, _depositRate, _partyGoal);
        

        for (uint256 i = 0; i < _approvedTokens.length; i++) {
            require(!tokenWhitelist[_approvedTokens[i]], "token duplicated");
            tokenWhitelist[_approvedTokens[i]] = true;
            approvedTokens.push(_approvedTokens[i]);
        }
        
        daoFee = _daoFee;
        periodDuration = _periodDuration;
        votingPeriodLength = _votingPeriodLength;
        gracePeriodLength = _gracePeriodLength;
        proposalDepositReward = _proposalDepositReward;
        depositRate = _depositRate;
        partyGoal = _partyGoal;
        summoningTime = now;
        name = _name;
        desc = _desc;
        status = NOT_SET;
        
        _addFounders(_founders); //had to move to internal function to avoid stack to deep issue 
        _setIdle(approvedTokens[1]);
    }
    
    /****************
    SUMMONING FUNCTIONS
    ****************/
    
    function _addFounders(address[] memory _founders) internal nonReentrant {
            for (uint256 i = 0; i < _founders.length; i++) {
            members[_founders[i]] = Member(_founders[i], 0, 0, 0, 0, 0, false, false);
            memberList.push(_founders[i]);
        }
    }
    
    function _setIdle(address _idleToken) internal nonReentrant {
        idleToken = IIdleToken(_idleToken);
    }
    
    
    function makeDeposit(address token, uint256 tribute) public nonReentrant {
        require(members[msg.sender].exists == true, "not member");
        require(tribute >= depositRate, "tribute insufficient");
        require(token == depositToken, "can only deposit depositToken");
        
        uint256 shares = tribute.div(depositRate);
        require(totalShares + shares <= MAX_INPUT, "shares maxed");
        
        if(memberList.length > 1) {
        require((members[msg.sender].shares.add(shares)) != (totalShares.add(shares)).div(uint256(2)), "can't buy 50%+ shares without a proposal");
        }
        
        members[msg.sender].shares += shares;
        totalShares += shares;
        
        if (userTokenBalances[GUILD][depositToken] == 0 && tribute > 0) {
            totalGuildBankTokens += 1;
        }
        
        depositToIdle(msg.sender, token, tribute);
        
        emit MakeDeposit(msg.sender, tribute, shares);
    }
    
    /****************
    MINION GOVERNANCE
    ****************/
    
    // NOTE: should be done programmatically so that it's the minion created w/ the contract
    function setMinion(address _minion) public nonReentrant {
        require(status != SET, "already set");
        minion = _minion;
        status = SET; // locks minion for moloch contract set on summoning
    }
    
    function amendGovernance(
        address _newToken,
        address _idleToken,
        address _minion,
        uint256 _partyGoal,
        uint256 _depositRate
    ) external nonReentrant {
        require(msg.sender == address(minion), "only minion can make these changes!");
        
        minion = _minion;
        depositRate = _depositRate;
        partyGoal = _partyGoal;
        
        if(_newToken != address(0)) {
            require(totalGuildBankTokens < MAX_TOKEN_WHITELIST_COUNT, "too many tokens already");
            require(!tokenWhitelist[address(_newToken)], "already whitelisted");
            approvedTokens.push(_newToken);
            totalGuildBankTokens += 1;
        }
        
        if(_idleToken != address(0)) {
            _setIdle(_idleToken);
        }
        
        emit AmendGovernance(_newToken, minion, depositRate);
    }

    /*****************
    PROPOSAL FUNCTIONS
    *****************/
    function submitProposal(
        address applicant,
        uint256 tributeOffered,
        uint256 sharesRequested,
        uint256 lootRequested,
        uint256 paymentRequested,
        uint256 flagNumber,
        address tributeToken,
        address paymentToken,
        bytes32 details
    ) public nonReentrant returns (uint256 proposalId) {
        require(sharesRequested.add(lootRequested) <= MAX_INPUT, "shares maxed");
        require(tokenWhitelist[paymentToken], "payment not whitelisted");
        require(applicant != address(0), "applicant cannot be 0");
        require(members[applicant].jailed == false, "applicant jailed");
        require(userTokenBalances[GUILD][depositToken] >= partyGoal, "goal not met yet");
        require(flagNumber != 0 || flagNumber != 1 || flagNumber != 2 || flagNumber != 3, "flag must be 4 - guildkick, 5 - spending, 6 - membership");

        // collect tribute from proposer and store it in the Moloch until the proposal is processed
        require(IERC20(paymentToken).transferFrom(msg.sender, address(this), proposalDepositReward), "proposal deposit failed");
        unsafeAddToBalance(ESCROW, paymentToken, proposalDepositReward);
        
        // check whether pool goal is met before allowing spending proposals
        if(flagNumber == 5) {
            require(userTokenBalances[GUILD][depositToken] >= partyGoal, "goal not met yet");
        }

        bool[7] memory flags; // [sponsored, processed, didPass, cancelled, guildkick, spending, member]
        flags[flagNumber] = true;
        
        if(flagNumber == 4) {
            _submitProposal(applicant, 0, 0, 0, address(0), 0, address(0), details, flags);
        } else {
            _submitProposal(applicant, sharesRequested, lootRequested, tributeOffered, tributeToken, paymentRequested,  paymentToken, details, flags);
        }

        // NOTE: Should approve the 0x address as a blank token for guildKick proposals where there's no token. 
        return proposalCount - 1; // return proposalId - contracts calling submit might want it
    }
    

function _submitProposal(
        address applicant,
        uint256 sharesRequested,
        uint256 lootRequested,
        uint256 tributeOffered,
        address tributeToken,
        uint256 paymentRequested,
        address paymentToken,
        bytes32 details,
        bool[7] memory flags
    ) internal {
        Proposal memory proposal = Proposal({
            applicant : applicant,
            proposer : msg.sender,
            sponsor : address(0),
            sharesRequested : sharesRequested,
            lootRequested : lootRequested,
            tributeOffered : tributeOffered,
            tributeToken : tributeToken,
            paymentRequested : paymentRequested,
            paymentToken : paymentToken,
            startingPeriod : 0,
            yesVotes : 0,
            noVotes : 0,
            flags : flags,
            details : details,
            maxTotalSharesAndLootAtYesVote : 0
        });

        proposals[proposalCount] = proposal;
        // NOTE: argument order matters, avoid stack too deep
        emit SubmitProposal(applicant, sharesRequested, lootRequested, tributeOffered, tributeToken, paymentRequested, paymentToken, details, flags, proposalCount, msg.sender);
        proposalCount += 1;
    }

    
    function sponsorProposal(uint256 proposalId) public nonReentrant  {
        Proposal storage proposal = proposals[proposalId];
        require(members[msg.sender].exists == true, "must be a member to sponsor");
        require(proposal.proposer != address(0), 'proposal must have been proposed');
        require(!proposal.flags[0], "proposal has already been sponsored");
        require(!proposal.flags[3], "proposal has been cancelled");

        // guild kick proposal
        if (proposal.flags[4]) { //  [sponsored, processed, didPass, cancelled, guildkick, spending, member]
            require(!proposedToKick[proposal.applicant], 'already proposed to kick');
            proposedToKick[proposal.applicant] = true;
        }

        // compute startingPeriod for proposal
        uint256 startingPeriod = max(
            getCurrentPeriod(),
            proposalQueue.length == 0 ? 0 : proposals[proposalQueue[proposalQueue.length.sub(1)]].startingPeriod
        ).add(1);

        proposal.startingPeriod = startingPeriod;
        
        proposal.sponsor = msg.sender;

        proposal.flags[0] = true; // sponsored

        // append proposal to the queue
        proposalQueue.push(proposalId);
        
        emit SponsorProposal(msg.sender, proposalId, proposalQueue.length.sub(1), startingPeriod);
    }



    // NOTE: In PoolParty proposalId = proposalIndex +1 since sponsorship is auto. 
    function submitVote(uint256 proposalIndex, uint8 uintVote) public nonReentrant  {
        address memberAddress = msg.sender;
        Member storage member = members[memberAddress];

        require(proposalIndex < proposalQueue.length, "proposal does not exist");
        require(members[memberAddress].exists == true, "must be a member to vote");
        Proposal storage proposal = proposals[proposalQueue[proposalIndex]];

        require(uintVote < 3, "must be less than 3, 0 = yes, 1 = no");
        Vote vote = Vote(uintVote);

        require(getCurrentPeriod() >= proposal.startingPeriod, "voting period has not started");
        require(!hasVotingPeriodExpired(proposal.startingPeriod), "proposal voting period has expired");
        require(proposal.votesByMember[memberAddress] == Vote.Null, "member has already voted");
        require(vote == Vote.Yes || vote == Vote.No, "vote must be either Yes or No");

        proposal.votesByMember[memberAddress] = vote;

        if (vote == Vote.Yes) {
            proposal.yesVotes = proposal.yesVotes.add(member.shares);

            // set highest index (latest) yes vote - must be processed for member to ragequit
            if (proposalIndex > member.highestIndexYesVote) {
                member.highestIndexYesVote = proposalIndex;
            }

            // set maximum of total shares encountered at a yes vote - used to bound dilution for yes voters
            if (totalShares.add(totalLoot) > proposal.maxTotalSharesAndLootAtYesVote) {
                proposal.maxTotalSharesAndLootAtYesVote = totalShares.add(totalLoot);
            }

        } else if (vote == Vote.No) {
            proposal.noVotes = proposal.noVotes.add(member.shares);
        }
     
        emit SubmitVote(proposalQueue[proposalIndex], proposalIndex, msg.sender, memberAddress, uintVote);
    }

    function processProposal(uint256 proposalIndex) public nonReentrant {
        _validateProposalForProcessing(proposalIndex);

        Proposal storage proposal = proposals[proposalQueue[proposalIndex]];

        require(!proposal.flags[3], "not standard proposal"); 

        proposal.flags[0] = true; // processed

        bool didPass = _didPass(proposalIndex);

        // Make the proposal fail if the new total number of shares and loot exceeds the limit
        if (totalShares.add(totalLoot).add(proposal.sharesRequested).add(proposal.lootRequested) > MAX_INPUT) {
            didPass = false;
        }

        // Make the proposal fail if it is requesting more tokens as payment than the available guild bank balance
        if (proposal.paymentRequested > userTokenBalances[GUILD][proposal.paymentToken]) {
            didPass = false;
        }

        // PROPOSAL PASSED
        if (didPass) {
            proposal.flags[1] = true; // didPass

            // if the applicant is already a member, add to their existing shares & loot
            if (members[proposal.applicant].exists) {
                members[proposal.applicant].shares = members[proposal.applicant].shares.add(proposal.sharesRequested);
                members[proposal.applicant].loot = members[proposal.applicant].loot.add(proposal.lootRequested);

            // the applicant is a new member, create a new record for them
            } else {

                // use applicant address as delegateKey by default
                members[proposal.applicant] = Member(proposal.applicant, proposal.sharesRequested, proposal.lootRequested, 0, 0, 0, false, true);
                memberList.push(proposal.applicant);
            }

            // mint new shares & loot
            totalShares = totalShares.add(proposal.sharesRequested);
            totalLoot = totalLoot.add(proposal.lootRequested);

            // if the proposal tribute is the first tokens of its kind to make it into the guild bank, increment total guild bank tokens
            if (userTokenBalances[GUILD][proposal.tributeToken] == 0 && proposal.tributeOffered > 0) {
                totalGuildBankTokens += 1;
            }

            unsafeInternalTransfer(ESCROW, GUILD, proposal.tributeToken, proposal.tributeOffered);
            if (proposal.tributeToken == depositToken) {
                depositToIdle(proposal.applicant, proposal.tributeToken, proposal.tributeOffered);
            }
            
            unsafeInternalTransfer(GUILD, proposal.applicant, proposal.paymentToken, proposal.paymentRequested);

            // if the proposal spends 100% of guild bank balance for a token, decrement total guild bank tokens
            if (userTokenBalances[GUILD][proposal.paymentToken] == 0 && proposal.paymentRequested > 0) {
                totalGuildBankTokens -= 1;
            }

        // PROPOSAL FAILED
        } else {
            // return all tokens to the proposer (not the applicant, because funds come from proposer)
            unsafeInternalTransfer(ESCROW, proposal.proposer, proposal.tributeToken, proposal.tributeOffered);
        }

        _returnDeposit();

        emit ProcessProposal(proposalIndex, didPass);
    }

    

    function processGuildKickProposal(uint256 proposalIndex) public nonReentrant {
        _validateProposalForProcessing(proposalIndex);

        uint256 proposalId = proposalQueue[proposalIndex];
        Proposal storage proposal = proposals[proposalId];

        require(proposal.flags[3], "not guild kick");

        proposal.flags[0] = true; //[processed, didPass, cancelled, guildkick, spending, member]

        bool didPass = _didPass(proposalIndex);

        if (didPass) {
            proposal.flags[1] = true; // didPass
            Member storage member = members[proposal.applicant];
            member.jailed == true;

            // transfer shares to loot
            member.loot = member.loot.add(member.shares);
            totalShares = totalShares.sub(member.shares);
            totalLoot = totalLoot.add(member.shares);
            member.shares = 0; // revoke all shares
        }

        proposedToKick[proposal.applicant] = false;

        _returnDeposit();

        emit ProcessGuildKickProposal(proposalIndex, proposalId, didPass);
    }

    function _didPass(uint256 proposalIndex) internal view returns (bool didPass) {
        Proposal memory proposal = proposals[proposalQueue[proposalIndex]];

        didPass = proposal.yesVotes > proposal.noVotes;

        // Make the proposal fail if the dilutionBound is exceeded
        if ((totalShares.add(totalLoot)).mul(dilutionBound) < proposal.maxTotalSharesAndLootAtYesVote) {
            didPass = false;
        }

        // Make the proposal fail if the applicant is jailed
        // - for standard proposals, we don't want the applicant to get any shares/loot/payment
        // - for guild kick proposals, we should never be able to propose to kick a jailed member (or have two kick proposals active), so it doesn't matter
        if (members[proposal.applicant].jailed != true) {
            didPass = false;
        }

        return didPass;
    }

    function _validateProposalForProcessing(uint256 proposalIndex) internal view {
        require(proposalIndex < proposalQueue.length, "no such proposal");
        Proposal memory proposal = proposals[proposalQueue[proposalIndex]];

        require(getCurrentPeriod() >= proposal.startingPeriod.add(votingPeriodLength).add(gracePeriodLength), "proposal not ready");
        require(proposal.flags[0] == false, "proposal has already been processed");
        require(proposalIndex == 0 || proposals[proposalQueue[proposalIndex.sub(1)]].flags[0], "previous proposal unprocessed");
    }

    function _returnDeposit() internal {
        unsafeInternalTransfer(ESCROW, msg.sender, depositToken, proposalDepositReward);
    }

    function ragequit(uint256 sharesToBurn, uint256 lootToBurn) public nonReentrant {
        require(members[msg.sender].shares.add(members[msg.sender].loot) > 0, "only users with balances can ragequit");
        _ragequit(msg.sender, sharesToBurn, lootToBurn);
    }

    function _ragequit(address memberAddress, uint256 sharesToBurn, uint256 lootToBurn) internal {
        uint256 initialTotalSharesAndLoot = totalShares.add(totalLoot);

        Member storage member = members[memberAddress];

        require(member.shares >= sharesToBurn, "insufficient shares");
        require(member.loot >= lootToBurn, "insufficient loot");

        require(canRagequit(member.highestIndexYesVote), "cannot ragequit until highest index proposal member voted YES on is processed");

        uint256 sharesAndLootToBurn = sharesToBurn.add(lootToBurn);

        // burn shares and loot
        member.shares = member.shares.sub(sharesToBurn);
        member.loot = member.loot.sub(lootToBurn);
        totalShares = totalShares.sub(sharesToBurn);
        totalLoot = totalLoot.sub(lootToBurn);
        

        for (uint256 i = 0; i < approvedTokens.length; i++) {
            uint256 amountToRagequit = fairShare(userTokenBalances[GUILD][approvedTokens[i]], sharesAndLootToBurn, initialTotalSharesAndLoot);
            if (amountToRagequit > 0) { // gas optimization to allow a higher maximum token limit
                userTokenBalances[GUILD][approvedTokens[i]] -= amountToRagequit;
                userTokenBalances[memberAddress][approvedTokens[i]] += amountToRagequit;
                
                if(member.iTokenRedemptions > 0) {
                    uint256 iTokenAdj = member.iTokenRedemptions;
                    unsafeInternalTransfer(memberAddress, GUILD, address(idleToken), iTokenAdj); 
                    member.iTokenRedemptions.add(amountToRagequit.sub(iTokenAdj));  
                }
            }
        }

        emit Ragequit(msg.sender, sharesToBurn, lootToBurn);
    }

    function ragekick(address memberToKick) public nonReentrant {
        Member storage member = members[memberToKick];

        require(member.jailed != true, "member not jailed");
        require(member.loot > 0, "member must have loot"); // note - should be impossible for jailed member to have shares
        require(canRagequit(member.highestIndexYesVote), "cannot ragequit until highest index proposal member voted YES on is processed");

        _ragequit(memberToKick, 0, member.loot);
    }

    function withdrawBalance(address token, uint256 amount) public nonReentrant {
        _withdrawBalance(token, amount);
    }
    
    function withdrawInterest(address memberAddress) public nonReentrant {
        require(members[memberAddress].exists == true, "not member");
        require(address(msg.sender) == memberAddress, "can only be called by member");
        
        uint256 earnings = getUserEarnings(msg.sender);
        uint256 iTokenPrice = IIdleToken(idleToken).tokenPrice();
        uint256 earningsTokens = earnings.div(iTokenPrice);
        
        require(earningsTokens > 0, "not enough earnings to redeem a token");
        members[memberAddress].iTokenRedemptions.add(earningsTokens);
    
        uint256 redeemedTokens = idleToken.redeemIdleToken(earningsTokens, false, new uint256[](0));
        // @DEV - see if we need to run a collectTokens function to collect the DAI and move to GUILD
        unsafeAddToBalance(GUILD, depositToken, redeemedTokens);
        unsafeInternalTransfer(GUILD, msg.sender, depositToken, redeemedTokens);
        _withdrawBalance(depositToken, redeemedTokens);
    }

    function withdrawBalances(address[] memory tokens, uint256[] memory amounts, bool max) public nonReentrant {
        require(tokens.length == amounts.length, "tokens + amounts arrays must match");

        for (uint256 i=0; i < tokens.length; i++) {
            uint256 withdrawAmount = amounts[i];
            if (max) { // withdraw the maximum balance
                withdrawAmount = userTokenBalances[msg.sender][tokens[i]];
            }

            _withdrawBalance(tokens[i], withdrawAmount);
        }
    }
    
    
    function _withdrawBalance(address token, uint256 amount) internal {
        require(userTokenBalances[msg.sender][token] >= amount, "insufficient balance");
        unsafeSubtractFromBalance(msg.sender, token, amount);
        require(IERC20(token).transfer(msg.sender, amount), "transfer failed");
        emit Withdraw(msg.sender, token, amount);
    }
    
    function withdrawFees() external {
        
        uint256 totalEarnings = getGuildEarnings();
        // Pool Fees = 20% of interest (i.e. if interest earnings = 5% then pool fees are 1%)
        uint256 poolFees = totalEarnings.mul(uint256(100).div(20));
        uint256 iTokenPrice = IIdleToken(idleToken).tokenPrice();
        uint256 feeTokens = poolFees.div(iTokenPrice);
        
        require(feeTokens > 1*10**18, "not enough fees to withdraw");
        require(IERC20(address(idleToken)).transfer(daoFee, feeTokens));
        unsafeSubtractFromBalance(GUILD, address(idleToken), feeTokens);
    }

    // NOTE: gives the DAO the ability to collect payments and also recover tokens just sent to DAO address (if whitelisted)
    function collectTokens(address token) external {
        uint256 amountToCollect = IERC20(token).balanceOf(address(this)) - userTokenBalances[TOTAL][token];
        // only collect if 1) there are tokens to collect and 2) token is whitelisted
        require(amountToCollect > 0, "no tokens");
        require(tokenWhitelist[token], "not whitelisted");
        
        if (userTokenBalances[GUILD][token] == 0 && totalGuildBankTokens < MAX_TOKEN_WHITELIST_COUNT) {
            totalGuildBankTokens += 1;
        }
        unsafeAddToBalance(GUILD, token, amountToCollect);

        emit TokensCollected(token, amountToCollect);
    }
    

    // NOTE: requires that delegate key which sent the original proposal cancels, msg.sender == proposal.proposer
    function cancelProposal(uint256 proposalId) public nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(getCurrentPeriod() <= proposal.startingPeriod, "voting period has already started");
        require(!proposal.flags[3], "proposal already cancelled");
        require(msg.sender == proposal.proposer, "only proposer cancels");

        proposal.flags[3] = true; // cancelled
        
        unsafeInternalTransfer(ESCROW, proposal.proposer, proposal.tributeToken, proposal.tributeOffered);
        emit CancelProposal(proposalId, msg.sender);
    }


    // can only ragequit if the latest proposal you voted YES on has been processed
    function canRagequit(uint256 highestIndexYesVote) public view returns (bool) {
        require(highestIndexYesVote < proposalQueue.length, "no such proposal");
        return proposals[proposalQueue[highestIndexYesVote]].flags[0];
    }

    function hasVotingPeriodExpired(uint256 startingPeriod) public view returns (bool) {
        return getCurrentPeriod() >= startingPeriod.add(votingPeriodLength);
    }
    
    /***************
    GETTER FUNCTIONS
    ***************/
    function max(uint256 x, uint256 y) internal pure returns (uint256) {
        return x >= y ? x : y;
    }

    function getCurrentPeriod() public view returns (uint256) {
        return now.sub(summoningTime).div(periodDuration);
    }

    function getProposalQueueLength() public view returns (uint256) {
        return proposalQueue.length;
    }

    function getProposalFlags(uint256 proposalId) public view returns (bool[7] memory) {
        return proposals[proposalId].flags;
    }

    function getUserTokenBalance(address user, address token) public view returns (uint256) {
        return userTokenBalances[user][token];
    }

    function getMemberProposalVote(address memberAddress, uint256 proposalIndex) public view returns (Vote) {
        require(members[memberAddress].exists, "no such member");
        require(proposalIndex < proposalQueue.length, "unproposed");
        return proposals[proposalQueue[proposalIndex]].votesByMember[memberAddress];
    }

    function getTokenCount() public view returns (uint256) {
        return approvedTokens.length;
    }

    /***************
    HELPER FUNCTIONS
    ***************/
    
    function getUserEarnings(address memberAddress) public returns (uint256) {
        uint256 userBalance = members[memberAddress].iTokenAmts.sub(members[memberAddress].iTokenRedemptions);
        uint256 avgCost = userBalance.mul(IIdleToken(idleToken).userAvgPrices(address(this))).div(10**18);
        uint256 currentValue = userBalance.mul(IIdleToken(idleToken).tokenPrice()).div(10**18);
        uint256 totalEarnings = currentValue.sub(avgCost);
        uint256 poolFees = totalEarnings.mul(uint256(100).div(20));
        uint256 earnings = totalEarnings.sub(poolFees);

        return earnings;
    }
    
    // *NOTE* - returns earnings inclusive of fees 
    function getGuildEarnings() public returns (uint256) {
        address user = address(this);
        uint256 userBalance = getUserTokenBalance(GUILD, address(idleToken));
        uint256 avgCost = userBalance.mul(idleToken.userAvgPrices(user)).div(10**18);
        uint256 currentValue = userBalance.mul(idleToken.tokenPrice()).div(10**18);
        uint256 totalEarnings = currentValue.sub(avgCost);
        
        return totalEarnings;
    }
    
    function depositToIdle(address depositor, address token, uint256 amount) internal {
        require(token == depositToken, "not able to deposit in idle");
        require(amount != 0, "no tokens to deposit");
        require(IERC20(address(idleToken)).approve(address(this), amount), 'approval failed');
        
        uint256 newIdle = IIdleToken(idleToken).mintIdleToken(amount, true);
        unsafeAddToBalance(GUILD, address(idleToken), newIdle);
        members[depositor].iTokenAmts.add(newIdle);
    }
    
    
    function unsafeAddToBalance(address user, address token, uint256 amount) internal {
        userTokenBalances[user][token] += amount;
        userTokenBalances[TOTAL][token] += amount;
    }

    function unsafeSubtractFromBalance(address user, address token, uint256 amount) internal {
        userTokenBalances[user][token] -= amount;
        userTokenBalances[TOTAL][token] -= amount;
    }

    function unsafeInternalTransfer(address from, address to, address token, uint256 amount) internal {
        unsafeSubtractFromBalance(from, token, amount);
        unsafeAddToBalance(to, token, amount);
    }

    function fairShare(uint256 balance, uint256 shares, uint256 totalSharesAndLoot) internal pure returns (uint256) {
        require(totalSharesAndLoot != 0);

        if (balance == 0) { return 0; }

        uint256 prod = balance * shares;

        if (prod / balance == shares) { // no overflow in multiplication above?
            return prod / totalSharesAndLoot;
        }

        return (balance / totalSharesAndLoot) * shares;
    }  
}