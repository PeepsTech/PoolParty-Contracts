pragma solidity 0.5.17;

import "./CloneParty.sol";
import "./CloneFactory.sol";

// ["0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa","0x295CA5bC5153698162dDbcE5dF50E436a58BA21e"] kDAI, kIdleDAI
// ["0xDE2C7c260C851c0AF3db31409D0585bbE9D20a78","0x7136fbDdD4DFfa2369A9283B6E90A040318011Ca","0x3792acDf2A8658FBaDe0ea70C47b89cB7777A5a5"] test members
// 1000000000000000000
// 0x5465737450617274790a00000000000000000000000000000000000000000000

contract PartyStarter is CloneFactory {
    
    address public template;
    
    constructor (address _template) public {
        template = _template;
    }

    
    event PartyStarted(address indexed pty, address[] _founders, address[] _approvedTokens, address _daoFees, uint256 _periodDuration, uint256 _votingPeriodLength, uint256 _gracePeriodLength, uint256 _proposalDepositReward, uint256 _depositRate, uint256 _partyGoal, uint256 summoningTime, uint256 _dilutionBound);

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
        uint256 _dilutionBound
    ) public returns (address) {
       Party pty = Party(createClone(template));
      
       pty.init(
            _founders,
            _approvedTokens,
            _daoFees,
            _periodDuration,
            _votingPeriodLength,
            _gracePeriodLength,
            _proposalDepositReward,
            _depositRate,
            _partyGoal,
            _dilutionBound);
        
        emit PartyStarted(address(pty), _founders, _approvedTokens, _daoFees, _periodDuration, _votingPeriodLength, _gracePeriodLength, _proposalDepositReward, _depositRate, _partyGoal, now, _dilutionBound);
        return address(pty);
    }
}