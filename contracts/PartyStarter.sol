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
        address _idleToken,
        uint256 _periodDuration,
        uint256 _votingPeriodLength,
        uint256 _gracePeriodLength,
        uint256 _proposalDeposit,
        uint256 _dilutionBound,
        uint256 _processingReward,
        uint256 _depositRate,
        uint256 _partyGoal,
        bytes32 _name
    ) public {
        party = new Party(
            _founders,
            _approvedTokens,
            _idleToken,
            _periodDuration,
            _votingPeriodLength,
            _gracePeriodLength,
            _proposalDeposit,
            _dilutionBound,
            _processingReward, 
            _depositRate,
            _partyGoal, 
            _name);
        
        minionSummoner.summonMinion(address(party), _approvedTokens[0]);// summons minion for new moloch
        emit PartyStarted(address(party));
    }
}