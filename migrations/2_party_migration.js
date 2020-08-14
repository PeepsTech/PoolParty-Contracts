  
var Party = artifacts.require("Party");

/*
address[] memory _founders,
address[] memory _approvedTokens, //deposit token in 0, idleToken in 1
address _daoFees,
uint256 _periodDuration,
uint256 _votingPeriodLength,
uint256 _gracePeriodLength,
uint256 _proposalDeposit,
uint256 _depositRate,
uint256 _partyGoal,
bytes32 _name,
bytes32 _desc
*/

const _founders = ["0xe0B7afD7d271f570499011eb4A5b682F46CCA5A9","0x7E8345d6BA37a98b5f7B196547A3C40F3126575B"];
const _approvedTokens = ["0x6B175474E89094C44Da98b954EedeAC495271d0F","0x78751b12da02728f467a44eac40f5cbc16bd7934"]; // DAI and IdleDAI
const _daoFees ="0x7136fbDdD4DFfa2369A9283B6E90A040318011Ca";
const _periodDuration = 60; //seconds
const _votingPeriodLength = 5;  //60 x 2 = 120 seconds
const _gracePeriodLength = 3;
const _proposalDepositReward = 2;
const _depositRate = 100;
const _partyGoal = 200;
const _name ="0x5465737450617274790a00000000000000000000000000000000000000000000";
const _desc ="0x486f7065207468697320776f726b732e200a0000000000000000000000000000";


var Party = artifacts.require("Party");


module.exports = function(deployer) {
    deployer.deploy(Party, _founders, _approvedTokens, _daoFees, _periodDuration,
    	_votingPeriodLength, _gracePeriodLength, _proposalDepositReward, _depositRate, _partyGoal, _name, _desc);
};
