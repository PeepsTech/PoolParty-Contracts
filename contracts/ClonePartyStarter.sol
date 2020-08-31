pragma solidity 0.5.17;

import "./PoolPartyClone.sol";
import "./CloneFactory.sol";

contract PartyStarter is CloneFactory {
    
    address public template;
    
    constructor (address _template) public {
        template = _template;
    }

    
    event PartyStarted(address indexed pty, address[] indexed _founders, address[] indexed _approvedTokens, address _daoFees, uint256 _periodDuration, uint256 _votingPeriodLength, uint256 _gracePeriodLength, uint256 _proposalDeposit, uint256 summoningTime);

    function startParty(
        address[] calldata _founders,
        address[] calldata _approvedTokens, //deposit token in 0, idleToken in 1
        address _daoFees,
        uint256 _periodDuration,
        uint256 _votingPeriodLength,
        uint256 _gracePeriodLength,
        uint256 _proposalDeposit,
        uint256 _depositRate,
        uint256 _partyGoal,
        bytes32 _name,
        bytes32 _desc
    ) external returns (address) {
       Party pty = Party(createClone(template));
       
       pty.init(
            _founders,
            _approvedTokens,
            _daoFees,
            _periodDuration,
            _votingPeriodLength,
            _gracePeriodLength,
            _proposalDeposit,
            _depositRate,
            _partyGoal,
            _name,
            _desc);
        
        emit PartyStarted(address(pty), _founders, _approvedTokens, _daoFees, _periodDuration, _votingPeriodLength, _gracePeriodLength, _proposalDeposit, now);
        return address(pty);
    }
}