# NFT Horcrux 
###  ( NFT Tokeniser v0.2 )

Improved liquidity and tokenising process

---

Take any ERC-721 compliant NFT and split ownership of that asset using an ERC-20 token.

Any NFT can be tokenised by the contract. The tokenising process transfers the NFT to the tokeniser, at which point a new fungible token is created, with the entire balance initially going to the creator. During token creation, the ETH value of the NFT is specified, this is used to help with liquidity.

After that, the NFT remains the property of the Tokeniser contract until someone liquidates it, or having a token balance equal to the total supply, withdraws it. 

When an NFT is liquidated, the liquidator provides ETH equal to the value of the NFT (less the share they own as tokens). The NFT is transferred to the liquidator, and the remaining token holders are able to withdraw their share of the deposited ETH.

When an NFT is withdrawn, NFT is transferred to the withdrawer, and the token contract is destroyed.

A liquidated NFT which still has un-claimed ETH can be solidated (re-tokenised) with the previously agreed NFT value and token supply. Any unclaimed ETH is transferred to the solidator and they receive all previously-cashed-out tokens.


Deployed on Kovan testnet at `0xc485eB25b7F380A22e11698413B20CA2A2546f94` for playing with.

--- 

## Tokenising

### Step 1. Approve

Because of gas limits in the ERC-721's `onERC721Received` function preventing writes, the first step is to approve the Tokeniser contract as an operator for the NFT you want to tokenise:

``` 
function approve(address _approved, uint256 _tokenId) external
 ``` 

This gives the Tokeniser contract permission to transfer the NFT, which it will do during the tokenisation process.

### Step 2. Tokenise

Then call the `tokenise` function on the Tokeniser contract:

```
tokenise(address _nftAddress,uint _tokenId, uint tokenCount, uint value) public returns(address newTokenAddress)
```

`tokenCount` is the total supply of ERC-20 tokens that will be minted.

`value` is the ETH value of the NFT being tokenised.

There is a constraint that `tokenCount * value < max value of uint256` in order to prevent overflows down the line. 

This function returns the address of the new fungible token contract for use by 3rd party contracts.

It also emits an event, further discussed below.

---

## Withdrawing

Withdrawing NFTs is easy and takes one step. 
If an address owns *all* of the corresponding tokens, then they just have to call `withdraw` on the Tokeniser contract. 

```
function withdraw(address _nftAddress,uint _tokenId) payable;
```

This self destructs the fungible token contract, and transfers the NFT to msg.sender.

If the withdrawer owns fewer than all of the corresponding tokens, they must pay the difference in ETH, which can be redeemed by the remaining token holders using the same function.

This function also emits an event, further discussed below.


---

## Liquidity

The primary purpose of this update was to improve liquidity, as originally an NFT would be locked up until the final token holdout handed over their tokens to whoever wanted to withdraw the NFT. This is why the `value` is set during tokenisation, token holders are implicitly agreeing to this valuation by accepting the tokens. 

A tokenised NFT, appropriately valued, can therefore be sold in pieces as needed. At any point, someone agreeing that the price is fair can liquidate the NFT (pay ETH for shares they don't own and withdraw the NFT).  If the NFT is undervalued, there's an economic incentive for someone to liquidate it at the lower price, and then sell it at a higher price. If the NTF is overvalued, the onus is on the valuer to re-tokenise at a lower price (as they initially hold all the tokens).

A liquidated NFT will, by definition, mean there are still tokens held by other people. The ETH value of these tokens is fixed until all have been redeemed. An NFT can be re-tokenised while there are still holdouts who haven't redeemed their ETH. This reverse liquidation process is called 'solidation', and uses the same `tokenise` function. Solidating an NFT will transfer any previously-redeemed tokens to the solidator, as well as any unredeemed ETH which was previously set aside for the other token holders. Solidation implicitly agrees on the previous NFT valuation.

If an NFT has been liquidated, and all token holders have redeemed their ETH, the NFT can be re-tokenised with a different valuation and token supply. This is done using the same `tokenise` function.

Liquidation, NFT withdrawal and redeeming ETH all use the same `withdraw` function.

## Events

The contract has five events:

    event Create(address indexed _nftAddress, uint indexed _tokenId, address location,uint value);

This event is emitted when an NFT is tokenised, or re-tokenised (but not solidated). It announces the declared value of the NFT, and the new token contract location.

    event Destroy(address indexed _nftAddress, uint indexed _tokenId, address location);

This event is emitted when an NFT is withdrawn and the token contract destroyed, or immediately prior to re-tokenisation for thoroughness. 

    event Liquidate(address indexed _nftAddress, uint indexed _tokenId, uint tokens);

This event is emitted when an NFT is liquidated, and announces how many corresponding tokens were burned in the process.

    event Solidate(address indexed _nftAddress, uint indexed _tokenId, uint tokens);

This event is emitted when an NFT is solidated, and announces how many corresponding tokens were re-issued to the solidator.

    event Withdraw(address indexed _nftAddress, uint indexed _tokenId, uint tokens);

This event is emitted when token holders redeem their ETH, and annouces how many corresponding tokens were burned in the process.



---
Note: `name()` and `symbol()` for the fungible tokens is just the value from the NFT concatenated to the tokenId in reverse. This is sloppy but I intend to clean it up in a future version.

--- 

Shout out: I stole most of the ERC-20 code from [ConsenSys's implementation](https://github.com/ConsenSys/Tokens/blob/fdf687c69d998266a95f15216b1955a4965a0a6d/contracts/eip20/EIP20.sol).