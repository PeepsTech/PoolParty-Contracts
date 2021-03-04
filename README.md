
# Welcome to the Pool-Party 

Pool-Party DAOs are a fork of Molochv2 (https://github.com/MolochVentures/moloch) and owes a huge debt to the Moloch community and the devs that built Molochv1 and Molochv2. Pool-Parties take the Molochv2 code and allow for easier deposits for existing members, earnings / dividends, and a couple potential DeFi integrations (i.e. earn interest via Aave or Idle). Each type of party below has some unique attributes, so read more about them below. 

We're a small project, so our documentation is a WIP. This code is offerred under the GPL-3


## NOFI Party 
Launching a NOFI Party allows anyone to pool funds with friends and automatically using any ERC20 token. If that token is invested in assets that return more of that token in the form of earnings to the DAO, the members are able to see and withdraw their share of the profits. Earn together. Change the world.

`NOFIparty.sol` is built on the Moloch DAO v2 smart contracts. Therefore, it is a permissioned DAO that requires tribute and a confirming vote by existing members to deposit ETH (occurring on `processProposal`). However, existing members are able to deposit up to 50% of a Pool-Party's goal via the `deposit` function. 

Party members may also `ragequit` and liquidate their internal `shares` and `loot` balances into their fair share of tokens held in the DAO contract.

## WETH Party 
Launching a WETH Party allows anyone to pool funds with friends and automatically converts ETH tribute into WETH. If that WETH is invested in assets that return WETH earnings to the DAO, the members are able to see and withdraw their share of the profits. Earn together. Change the world.

`WETHparty.sol` is built on the Moloch DAO v2 smart contracts. Therefore, it is a permissioned DAO that requires tribute and a confirming vote by existing members to deposit ETH (occurring on `processProposal`). However, existing members are able to deposit up to 50% of a Pool-Party's goal via the `deposit` function. 

Party members may also `ragequit` and liquidate their internal `shares` and `loot` balances into their fair share of WETH held in the DAO contract.

## Idle Party 

Launching an Idle Party allows anyone to pool funds with friends and automatically convert such tribute to interest-bearing Idle Tokens (iTokens). Party members can see their pooled iToken balances grow in real-time. Earn together. Change the world.

`CloneParty.sol` is built on the Moloch DAO v2 smart contracts. Therefore, it is a permissioned DAO that requires tribute and a confirming vote by existing members to convert such tribute into iToken (occurring on `processProposal`). However, existing members are able to deposit up to 50% of a Pool-Party's goal via the `deposit` function. 

Party members may also `ragequit` and liquidate their internal `shares` and `loot` balances into their fair share of aToken held in the DAO contract.

Idle Party may also be used to fund other projects with an iToken. 

## Aave Party 👻🏊🎉

*Development led by Ross Campbell 

Launching an Aave Party allows anyone to pool funds with friends and automatically convert such tribute to interest-bearing Aave Tokens (aTokens). Party members can see their pooled aToken balances grow in real-time. Earn together. Change the world.

`AaveParty.sol` is built on the Moloch DAO v2 smart contracts. Therefore, it is a permissioned DAO that requires tribute and a confirming vote by existing members to convert such tribute into aToken (occurring on `processProposal`).

Party members may also `ragequit` and liquidate their internal `shares` and `loot` balances into their fair share of aToken held in the DAO contract.

Aave Party may also be used to fund other projects with aToken. 

## License 

This code is offered without any warranties under the GPL-3.0 license:
https://www.gnu.org/licenses/gpl-3.0.en.html


