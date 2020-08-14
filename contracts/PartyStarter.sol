pragma solidity 0.5.17;

import "./Party.sol";

contract PartyStarter {
    Party private party;

    
    event PartyStarted(address indexed party, address[] indexed _founders, address[] indexed _approvedTokens, address _daoFees, uint256 _periodDuration, uint256 _votingPeriodLength, uint256 _gracePeriodLength, uint256 _proposalDepositReward, uint256 summoningTime);

    function startParty(
        address[] memory _founders,
        address[] memory _approvedTokens, //deposit token in 0, idleToken in 1
        address _daoFees,
        uint256 _periodDuration,
        uint256 _votingPeriodLength,
        uint256 _gracePeriodLength,
        uint256 _proposalDepositReward,
        uint256 _depositRate,
        uint256 _partyGoal,
        bytes32 _name,
        bytes32 _desc
    ) public {
        party = new Party(
            _founders,
            _approvedTokens,
            _daoFees,
            _periodDuration,
            _votingPeriodLength,
            _gracePeriodLength,
            _proposalDepositReward,
            _depositRate,
            _partyGoal,
            _name,
            _desc);
            
        uint256 summoningTime = now;     
        
        emit PartyStarted(address(party), _founders, _approvedTokens, _daoFees, _periodDuration, _votingPeriodLength, _gracePeriodLength, _proposalDepositReward, summoningTime);
    }
}