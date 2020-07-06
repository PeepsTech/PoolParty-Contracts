pragma solidity 0.5.17;

import "./PoolParty.sol";
import "./ISummonMinion.sol";

contract PartyStarter {
    Party private party;
    ISummonMinion public minionSummoner;
    
    event PartyStarted(address indexed party);

    constructor(address _minionSummoner) public { // locks minionSummoner to contract set
        minionSummoner = ISummonMinion(_minionSummoner);
        minionSummoner.setMolochSummoner(address(this));
    }

    function startParty(
        address[] memory _founders,
        address[] memory _approvedTokens,
        uint256 _periodDuration,
        uint256 _votingPeriodLength,
        uint256 _gracePeriodLength,
        uint256 _proposalDeposit,
        uint256 _dilutionBound,
        uint256 _processingReward,
        uint256 _depositRate,
        uint256 _partyGoal,
        address _idleContract,
        bytes32 _name, 
        bytes32 _manifesto
    ) public {
        party = new Party(
            _founders,
            _approvedTokens,
            _periodDuration,
            _votingPeriodLength,
            _gracePeriodLength,
            _proposalDeposit,
            _dilutionBound,
            _processingReward, 
            _depositRate,
            _partyGoal,
            _idleContract, // needs to be set based on DAI vs. USDC on front-end
            _name, 
            _manifesto);
        
        minionSummoner.summonMinion(address(party), _approvedTokens[0]);// summons minion for new moloch
        emit PartyStarted(address(party));
    }
}