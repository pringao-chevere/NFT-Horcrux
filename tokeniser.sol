//SPDX-License-Identifier: Give Me Cake

pragma solidity ^0.7.1;

contract Tokeniser{

    struct Asset{
        address depositer;
        address location;
    }

    mapping(address => mapping(uint => Asset)) assets;

    event Create(address indexed _nftAddress, uint indexed _tokenId, address location);
    event Destroy(address indexed _nftAddress, uint indexed _tokenId, address location);

    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes calldata _data) external returns(bytes4){
        require(assets[msg.sender][_tokenId].depositer == _from,'unprimed');
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }

    function prime(address _nftAddress,uint _tokenId) public{
        Partial721 asset = Partial721(_nftAddress);
        require(asset.ownerOf(_tokenId) == msg.sender,'not_owner');

        assets[_nftAddress][_tokenId].depositer = msg.sender;
    }

    function tokenise(address _nftAddress,uint _tokenId, uint tokenCount) public returns(address newTokenAddress){
        Partial721 asset = Partial721(_nftAddress);
        require(asset.ownerOf(_tokenId) == address(this),'not_sent');
        require(assets[_nftAddress][_tokenId].depositer == msg.sender,'not_depositer');
        require(tokenCount > 0,'tokenCount');

        delete assets[_nftAddress][_tokenId].depositer;

        TokenisedAsset token = new TokenisedAsset(tokenCount,msg.sender,_nftAddress,_tokenId);

        assets[_nftAddress][_tokenId].location = address(token);

        emit Create(_nftAddress,_tokenId,address(token));

        return address(token);
    }
    function withdraw(address _nftAddress,uint _tokenId) public{
        // require(assets[_nftAddress][_tokenId].tokenCount != 0,'not_tokenised');

        TokenisedAsset token = TokenisedAsset(assets[_nftAddress][_tokenId].location);

        require(token.balanceOf(msg.sender) == token.totalSupply(),'partial_owner');

        Partial721 asset = Partial721(_nftAddress);
        emit Destroy(_nftAddress,_tokenId,address(asset));

        asset.transferFrom(address(this),msg.sender,_tokenId);
        token.kill();

        delete assets[_nftAddress][_tokenId];


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
        require(balances[_from] >= _value && thisAllowance >= _value);
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
}