pragma solidity 0.6.12;
// SPDX-License-Identifier: MIT

library SafeMath { // arithmetic wrapper for under/overflow check
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

interface IERC20 { // brief interface for moloch erc20 token txs
    function balanceOf(address who) external view returns (uint256);
    
    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);
    
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IAaveDepositWithdraw {
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address token, uint256 amount, address destination) external;
    function getReservesList() external view returns (address[] memory);
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
}

contract testApool {
    using SafeMath for uint256;
    address aave = 0xE0fBa4Fc209b4948668006B2bE61711b7f465bAe;
    uint256 public depositRate = 100000000000000000000;
    uint256 public totalShares;
    uint256 public totalLoot;
    address public depositToken = 0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD;
    address public constant TOTAL = address(0xbabe);
    
    mapping(address => mapping(address => uint256)) public userTokenBalances; // userTokenBalances[userAddress][tokenAddress]
    mapping(address => mapping(address => uint256)) public userTokenRedemptions; //
    mapping(address => Member) public members;
    address[] public memberList;
    address[] public approvedTokens;
    mapping(address => address) public aTokenAssignments;
    
    constructor() public {
        members[msg.sender].exists = true;
        memberList.push(msg.sender);
        IERC20(depositToken).approve(aave, uint256(-1));
        approvedTokens.push(depositToken);
        aTokenAssignments[0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD] = 0xdCf0aF9e59C002FA3AA091a46196b37530FD48a8;
    }
    
    struct Member {
        uint256 shares; // the # of voting shares assigned to this member
        uint256 loot; // the loot amount available to this member (combined with shares on ragequit)
        uint256[] aTokenRedemptions; // interest withdrawn from array of approvedTokens (reflecting burn of accumulated aTokens)
        uint256 highestIndexYesVote; // highest proposal index # on which the member voted YES
        bool jailed; // set to proposalIndex of a passing guild kick proposal for this member, prevents voting on and sponsoring proposals
        bool exists; // always true once a member has been created
    }
    
    // MONEY DEPOSIT
    function makeDeposit(uint256 amount) external {
        require(members[msg.sender].exists == true, 'must be member to deposit shares');
        
        uint256 shares = amount.div(depositRate);
        members[msg.sender].shares += shares;
        //require(members[msg.sender].shares <= partyGoal.div(depositRate).div(2), "can't take over 50% of the shares w/o a proposal");
        totalShares += shares;
        
        require(IERC20(depositToken).transferFrom(msg.sender, address(this), amount), "token transfer failed");
        IAaveDepositWithdraw(aave).deposit(depositToken, amount, address(this), 0); // deposit to aave - return aToken to guild balance (not internal accounting)
        
        // Checks to see if goal has been reached with this deposit
        //goalHit = checkGoal();
        
        //emit MakeDeposit(msg.sender, amount, shares, goalHit);
    }
    
    // HELPER
    function fairShare(uint256 balance, uint256 shares, uint256 initTotalShares) internal pure returns (uint256) {
        require(initTotalShares != 0);

        if (balance == 0) { return 0; }

        uint256 prod = balance * shares;

        if (prod / balance == shares) { // no overflow in multiplication above?
            return prod / initTotalShares;
        }

        return (balance / initTotalShares) * shares;
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
    
    function getGuildBalances(address token) external view returns (uint256) {
        return IERC20(aTokenAssignments[token]).balanceOf(address(this));
    }
    
    function getFairShare(address token) external view returns (uint256) {
        uint256 initialTotalSharesAndLoot = totalShares.add(totalLoot);
        Member storage member = members[msg.sender];
        require(member.exists == true, "not member");
        uint256 sharesAndLootM = member.shares.add(member.loot);
        return fairShare(IERC20(aTokenAssignments[token]).balanceOf(address(this)), sharesAndLootM, initialTotalSharesAndLoot);
    }    
    
    function getMemberRedemptions(address member) external view returns (uint256[] memory) {
        return members[member].aTokenRedemptions;
    }
    
    // WITHDRAW 
    function withdrawEarnings(address token, uint256 amount) external {
        uint256 initialTotalSharesAndLoot = totalShares.add(totalLoot);
        
        Member storage member = members[msg.sender];
        require(member.exists == true, "not member");
        uint256 sharesAndLootM = member.shares.add(member.loot);
        
        uint256 share = fairShare(IERC20(aTokenAssignments[token]).balanceOf(address(this)), sharesAndLootM, initialTotalSharesAndLoot);
        uint256 claimable = share - userTokenRedemptions[msg.sender][token];
        require(claimable >= amount, "insufficient earnings");
        uint256 fee = amount.div(uint256(100)).div(2); // 2% fee on claimed earnings
        uint256 claim = amount.sub(fee);
            
        IAaveDepositWithdraw(aave).withdraw(token, claim, address(this));
        unsafeAddToBalance(msg.sender, token, claim);
            
        userTokenRedemptions[msg.sender][token] += claim;
    }
    
    function withdrawBalance(address token, uint256 amount) public {
        _withdrawBalance(token, amount);
    }
    
    function withdrawBalances(address[] memory tokens, uint256[] memory amounts, bool max) public {
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
        //emit Withdraw(msg.sender, token, amount);
    }
}

