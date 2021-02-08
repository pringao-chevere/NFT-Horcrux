//SPDX-License-Identifier: Give Me Cake
//Version 0.2 - increased liquidity and clean up transfer

pragma solidity ^0.7.1;

contract Tokeniser{

    struct Asset{
        uint value;
        address location;
        bool liquidated;
    }

    mapping(address => mapping(uint => Asset)) assets;

    event Create(address indexed _nftAddress, uint indexed _tokenId, address location,uint value);
    event Destroy(address indexed _nftAddress, uint indexed _tokenId, address location);
    event Withdraw(address indexed _nftAddress, uint indexed _tokenId, uint tokens);
    event Liquidate(address indexed _nftAddress, uint indexed _tokenId, uint tokens);
    event Solidate(address indexed _nftAddress, uint indexed _tokenId, uint tokens);


    function get_value(address _nftAddress,uint _tokenId) external view returns(uint){
        return assets[_nftAddress][_tokenId].value;
    }
    function liquidated(address _nftAddress,uint _tokenId) external view returns(bool){
        return assets[_nftAddress][_tokenId].liquidated;
    }

    function tokenise(address _nftAddress,uint _tokenId, uint tokenCount, uint value) public returns(address newTokenAddress){
        Partial721 asset = Partial721(_nftAddress);
        TokenisedAsset token;

        require(asset.getApproved(_tokenId) == address(this),'not_approved');

        address owner = asset.ownerOf(_tokenId);
        asset.transferFrom(owner,address(this),_tokenId);

        if(assets[_nftAddress][_tokenId].liquidated){
            token = TokenisedAsset(assets[_nftAddress][_tokenId].location);
            uint balance = token.balanceOf(address(this));
            uint totalSupply = token.totalSupply();
            if(balance != totalSupply){
                //Redeposit;
                payable(owner).transfer(balance * assets[_nftAddress][_tokenId].value / totalSupply);
                token.transfer(owner,balance);
                emit Solidate(_nftAddress,_tokenId,balance);
                return address(token);
            }
            //Remint
            assets[_nftAddress][_tokenId].liquidated = false;
            emit Destroy(_nftAddress, _tokenId,address(token));
            token.resupply(totalSupply,owner);
        }else{
            token = new TokenisedAsset(tokenCount,owner,_nftAddress,_tokenId);
            assets[_nftAddress][_tokenId].location = address(token);
        }
        require(tokenCount > 0,'tokenCount');
        require(value > 0,'value');
        require(value >= tokenCount && value % tokenCount == 0,'divisibility');

        uint256 totalValue = tokenCount * value;
        require(totalValue / tokenCount == value,'overflow');

        assets[_nftAddress][_tokenId].value = value;

        emit Create(_nftAddress,_tokenId,address(token),value);

        return address(token);
    }

    function withdraw(address _nftAddress,uint _tokenId) payable public {
        TokenisedAsset token = TokenisedAsset(assets[_nftAddress][_tokenId].location);

        if(assets[_nftAddress][_tokenId].liquidated){
            //Take ETH
            uint balance = token.balanceOf(msg.sender);
            token.transferFrom(msg.sender,address(this),balance);
            emit Withdraw(_nftAddress,_tokenId,balance);
            msg.sender.transfer(balance * assets[_nftAddress][_tokenId].value / token.totalSupply());

        }else if(token.balanceOf(msg.sender) == token.totalSupply()){
            //Full withdrawal
            Partial721 asset = Partial721(_nftAddress);
            emit Destroy(_nftAddress,_tokenId,address(asset));

            asset.transferFrom(address(this),msg.sender,_tokenId);
            token.kill();

            delete assets[_nftAddress][_tokenId];
        }else{
            //Liquidate
            uint balance = token.balanceOf(msg.sender);
            uint totalSupply = token.totalSupply();
            require(msg.value == (totalSupply - balance) * assets[_nftAddress][_tokenId].value / totalSupply,'value');
            assets[_nftAddress][_tokenId].liquidated = true;
            Partial721 asset = Partial721(_nftAddress);


            emit Liquidate(_nftAddress,_tokenId,balance);
            asset.transferFrom(address(this),msg.sender,_tokenId);
        }
    }

    function get_name(address _nftAddress, uint _tokenId) public view returns(string memory){
        Partial721 token = Partial721(_nftAddress);
        return concat(token.name(),_tokenId);
    }
    function get_symbol(address _nftAddress, uint _tokenId) public view returns(string memory){
        Partial721 token = Partial721(_nftAddress);
        return concat(token.symbol(),_tokenId);
    }
    function concat(string memory start,uint end) private pure returns(string memory){
        bytes memory num = '';
        while(end > 0){
            uint r = end % 10;
            end /= 10;
            num = abi.encodePacked(num,r +48 );
        }
        return string(abi.encodePacked(start,'-',num));
    }


}

interface Partial721 {
    function symbol() external view returns (string memory _symbol);
    function name() external view returns (string memory _name);
    function ownerOf(uint256 _tokenId) external view returns(address);
    function transferFrom(address _from, address _to, uint256 _tokenId) external;
    function getApproved(uint256 _tokenId) external view returns (address);
}


contract TokenisedAsset{
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    uint256 public totalSupply;
    uint256 constant MAX_UINT256 = 2**256 - 1;

    mapping (address => uint256) public balances;
    mapping (address => mapping (address => uint256)) public allowed;


    function name() public view returns (string memory){
        return parent.get_name(nftAddress,tokenId);
    }
    function symbol() public view returns (string memory){
        return parent.get_symbol(nftAddress,tokenId);
    }

    uint8 public decimals = 18;
    Tokeniser parent;
    address nftAddress;
    uint tokenId;

    constructor(
        uint256 _initialAmount,
        address minter,
        address _nftAddress,
        uint _tokenId
    ) {
        parent = Tokeniser(msg.sender);
        nftAddress = _nftAddress;
        tokenId = _tokenId;
        balances[minter] = _initialAmount;
        totalSupply = _initialAmount;
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balances[msg.sender] >= _value);
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        uint256 thisAllowance = allowed[_from][msg.sender];
        require(balances[_from] >= _value && thisAllowance >= _value || msg.sender == address(parent));

        balances[_to] += _value;
        balances[_from] -= _value;
        if (thisAllowance < MAX_UINT256) {
            allowed[_from][msg.sender] -= _value;
        }
        emit Transfer(_from, _to, _value);
        return true;
    }


    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    function kill() public{
        require(msg.sender == address(parent),'not_parent');
        selfdestruct(payable(address(parent)));
    }
    function resupply(uint newSupply,address minter) public{
        require(msg.sender == address(parent),'not_parent');

        if(newSupply > totalSupply){
            //mint
            emit Transfer(address(0), minter, newSupply - totalSupply);
        }else if(newSupply < totalSupply){
            //burn
            emit Transfer(minter,address(0), totalSupply - newSupply);
        }
        balances[minter] = newSupply;
        totalSupply = newSupply;
    }
}