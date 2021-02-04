# NFT Horcrux 
###  ( NFT Tokeniser )

---

Take any ERC-721 compliant NFT and split ownership of that asset using an ERC-20 token.

Any NFT can be sent to the contract, then a new fungible token is created, with the entire balance initially going to the creator. After that, the NFT remains the property of the Tokeniser contract until someone with a balance equal to the total supply withdraws it, at which point the ERC-20 contract is destroyed.

Deployed on Kovan testnet at `0x72253babDF6ABdF09F90caA3640898A111F74795` for playing with.

--- 

## Tokenising

### Step 1. Prime
Because of gas limits in the ERC-721's `onERC721Received` function preventing writes, the first step is to call the `prime` function on the Tokeniser contract:

``` 
function prime(address _nftAddress,uint _tokenId)
 ``` 

This tells the contract you're about to deposit a specific NFT from your current address.

### Step 2. SafeTransferFrom

Next, transfer the NFT to the Tokeniser contract using `SafeTransferFrom`:

```
function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory data) public
``` 

This transaction will fail if you haven't primed it properly, but no such check is possible with `transferFrom`, so make sure you use the former to be safe. Otherwise you risk losing your NFT.

If you do use the latter and you have primed the contract, then it will still work fine.

### Step 3. Tokensise

Last call the `Tokenise` function on the Tokeniser contract:

```
function tokenise(address _nftAddress,uint _tokenId, uint tokenCount) public returns(address newTokenAddress)
```

You can specify how many fungible tokens you want to split your NFT into. Function returns the address of the new fungible token contract in case you need it. Also emits an event.

---

## Withdrawing

Withdrawing NFTs is easy and takes one step. If an address owns *all* of the corresponding tokens, then they just have to call `withdraw` on the Tokeniser contract. It will fail if they don't.

```
function withdraw(address _nftAddress,uint _tokenId) public
```

This self destructs the fungible token contract, and transfers the NFT to msg.sender.


---
Note: `name()` and `symbol()` for the fungible tokens is just the value from the NFT concatenated to the tokenId in reverse. This is sloppy but I didn't think it mattered for a proof of concept.

--- 

Shout out: I stole most of the ERC-20 code from [ConsenSys's implementation](https://github.com/ConsenSys/Tokens/blob/fdf687c69d998266a95f15216b1955a4965a0a6d/contracts/eip20/EIP20.sol).  

