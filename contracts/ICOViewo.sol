pragma solidity ^0.4.18;

// ----------------------------------------------------------------------------
//
// VWO Viewo token public sale contract
//
// For details, please visit: www.viewo.com
//
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
//
// SafeMath3
//
// Adapted from https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/contracts/math/SafeMath.sol
// (no need to implement division)
//
// ----------------------------------------------------------------------------

library SafeMath3 {

  function mul(uint a, uint b) internal constant returns (uint c) {
    c = a * b;
    assert( a == 0 || c / a == b );
  }

  function sub(uint a, uint b) internal constant returns (uint) {
    assert( b <= a );
    return a - b;
  }

  function add(uint a, uint b) internal constant returns (uint c) {
    c = a + b;
    assert( c >= a );
  }

}


// ----------------------------------------------------------------------------
//
// Owned contract
//
// ----------------------------------------------------------------------------

contract Owned {

  address public owner;
  address public newOwner;

  // Events ---------------------------

  event OwnershipTransferProposed(address indexed _from, address indexed _to);
  event OwnershipTransferred(address indexed _from, address indexed _to);

  // Modifier -------------------------

  modifier onlyOwner {
    require( msg.sender == owner );
    _;
  }

  // Functions ------------------------

  function Owned() {
    owner = msg.sender;
  }

  function transferOwnership(address _newOwner) onlyOwner {
    require( _newOwner != owner );
    require( _newOwner != address(0x0) );
    OwnershipTransferProposed(owner, _newOwner);
    newOwner = _newOwner;
  }

  function acceptOwnership() {
    require(msg.sender == newOwner);
    OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}


// ----------------------------------------------------------------------------
//
// ERC Token Standard #20 Interface
// https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md
//
// ----------------------------------------------------------------------------

contract ERC20Interface {

  // Events ---------------------------

  event Transfer(address indexed _from, address indexed _to, uint _value);
  event Approval(address indexed _owner, address indexed _spender, uint _value);

  // Functions ------------------------

  function totalSupply() constant returns (uint);
  function balanceOf(address _owner) constant returns (uint balance);
  function transfer(address _to, uint _value) returns (bool success);
  function transferFrom(address _from, address _to, uint _value) returns (bool success);
  function approve(address _spender, uint _value) returns (bool success);
  function allowance(address _owner, address _spender) constant returns (uint remaining);

}


// ----------------------------------------------------------------------------
//
// ERC Token Standard #20
//
// ----------------------------------------------------------------------------

contract ERC20Token is ERC20Interface, Owned {
  
  using SafeMath3 for uint;

  uint public tokensIssuedTotal = 0;
  mapping(address => uint) balances;
  mapping(address => mapping (address => uint)) allowed;

  // Functions ------------------------

  /* Total token supply */

  function totalSupply() constant returns (uint) {
    return tokensIssuedTotal;
  }

  /* Get the account balance for an address */

  function balanceOf(address _owner) constant returns (uint balance) {
    return balances[_owner];
  }

  /* Transfer the balance from owner's account to another account */

  function transfer(address _to, uint _amount) returns (bool success) {
    // amount sent cannot exceed balance
    require( balances[msg.sender] >= _amount );

    // update balances
    balances[msg.sender] = balances[msg.sender].sub(_amount);
    balances[_to]        = balances[_to].add(_amount);

    // log event
    Transfer(msg.sender, _to, _amount);
    return true;
  }

  /* Allow _spender to withdraw from your account up to _amount */

  function approve(address _spender, uint _amount) returns (bool success) {
    // approval amount cannot exceed the balance
    require ( balances[msg.sender] >= _amount );
      
    // update allowed amount
    allowed[msg.sender][_spender] = _amount;
    
    // log event
    Approval(msg.sender, _spender, _amount);
    return true;
  }

  /* Spender of tokens transfers tokens from the owner's balance */
  /* Must be pre-approved by owner */

  function transferFrom(address _from, address _to, uint _amount) returns (bool success) {
    // balance checks
    require( balances[_from] >= _amount );
    require( allowed[_from][msg.sender] >= _amount );

    // update balances and allowed amount
    balances[_from]            = balances[_from].sub(_amount);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_amount);
    balances[_to]              = balances[_to].add(_amount);

    // log event
    Transfer(_from, _to, _amount);
    return true;
  }

  /* Returns the amount of tokens approved by the owner */
  /* that can be transferred by spender */

  function allowance(address _owner, address _spender) constant returns (uint remaining) {
    return allowed[_owner][_spender];
  }

}


// ----------------------------------------------------------------------------
//
// Viewo public token sale
//
// ----------------------------------------------------------------------------

contract ViewoToken is ERC20Token {

  /* Utility variable */
  
  uint constant M1 = 10**6; //1 million
  
  /* Basic token data */

  string public constant name     = "Viewo Coin";
  string public constant symbol   = "VEO";
  uint8  public constant decimals = 18;

  /* Wallet addresses - initially set to owner at deployment */
  
  address public wallet;
  address public adminWallet;

  /* ICO dates */

  uint public constant DATE_PRESALE_START = 1541808000; // 10-Nov-2018 00:00 UTC
  uint public constant DATE_PRESALE_END   = 1544400000; // 10-Dec-2018 00:00 UTC

  uint public constant DATE_ICO_START = 1544486400; // 11-Dec-2018 00:00 UTC
  uint public constant DATE_ICO_END   = 1547164800; // 11-Jan-2019 00:00 UTC

  /* ICO tokens per ETH */
  
  uint public tokensPerEth = 3200 * M1; // rate during last ICO week

  uint public constant BONUS_PRESALE      = 40;
  uint public constant BONUS_ICO_WEEK_ONE = 0;
  uint public constant BONUS_ICO_WEEK_TWO = 0;

  /* Other ICO parameters */  
  
  uint public constant TOKEN_SUPPLY_TOTAL = 2000000000; // 2 billion - Total Token Supply
  uint public constant TOKEN_SUPPLY_ICO   = 564062500; // 564,062,500 - Token Supply for Sale at ICO price
  uint public constant TOKEN_SUPPLY_MKT   =  1435937500; // 1,435,937,500 - Total Supply Minus ICO

  uint public constant PRESALE_ETH_CAP =  15000 ether;

  
  uint public constant MIN_CONTRIBUTION = 1 ether / 2; // 0.5 Ether
  uint public constant MAX_CONTRIBUTION = 3000 ether;

  /* Crowdsale variables */

  uint public icoEtherReceived = 0; // Ether actually received by the contract

  uint public tokensIssuedIco   = 0;
  uint public tokensIssuedMkt   = 0;
  
  /* Keep track of Ether contributed and tokens received during Crowdsale */
  
  mapping(address => uint) public icoEtherContributed;
  mapping(address => uint) public icoTokensReceived;

  // Events ---------------------------
  
  event WalletUpdated(address _newWallet);
  event AdminWalletUpdated(address _newAdminWallet);
  event TokensPerEthUpdated(uint _tokensPerEth);
  event TokensMinted(address indexed _owner, uint _tokens, uint _balance);
  event TokensIssued(address indexed _owner, uint _tokens, uint _balance, uint _etherContributed);
  event Refund(address indexed _owner, uint _amount, uint _tokens);

  // Basic Functions ------------------

  /* Initialize (owner is set to msg.sender by Owned.Owned() */

  function ViewoToken() {
    require( TOKEN_SUPPLY_ICO + TOKEN_SUPPLY_MKT == TOKEN_SUPPLY_TOTAL );
    wallet = owner;
    adminWallet = owner;
  }

  /* Fallback */
  
  function () payable {
    buyTokens();
  }
  
  // Information functions ------------
  
  /* What time is it? */
  
  function atNow() constant returns (uint) {
    return now;
  }
 
  
  /* Are tokens transferable? */

  function isTransferable() constant returns (bool transferable) {
     if ( atNow() < DATE_ICO_END ) return false;
     return true;
  }
  
 
  // Owner Functions ------------------
  
  /* Change the crowdsale wallet address */

  function setWallet(address _wallet) onlyOwner {
    require( _wallet != address(0x0) );
    wallet = _wallet;
    WalletUpdated(wallet);
  }

  /* Change the admin wallet address */

  function setAdminWallet(address _wallet) onlyOwner {
    require( _wallet != address(0x0) );
    adminWallet = _wallet;
    AdminWalletUpdated(adminWallet);
  }

  /* Change tokensPerEth before ICO start */
  
  function updateTokensPerEth(uint _tokensPerEth) onlyOwner {
    require( atNow() < DATE_PRESALE_START );
    tokensPerEth = _tokensPerEth;
    TokensPerEthUpdated(_tokensPerEth);
  }

  /* Minting of marketing tokens by owner */

  function mintToken(address _participant, uint _tokens) public onlyOwner {
    // check amount
    require( _tokens <= TOKEN_SUPPLY_MKT.sub(tokensIssuedMkt) );
    
    // update balances
    balances[_participant] = balances[_participant].add(_tokens);
    tokensIssuedMkt        = tokensIssuedMkt.add(_tokens);
    tokensIssuedTotal      = tokensIssuedTotal.add(_tokens);
    
    // log the miniting
    Transfer(0x0, _participant, _tokens);
    TokensMinted(_participant, _tokens, balances[_participant]);
  }

  /* Transfer out any accidentally sent ERC20 tokens */

  function transferAnyERC20Token(address tokenAddress, uint amount) onlyOwner returns (bool success) {
      return ERC20Interface(tokenAddress).transfer(owner, amount);
  }

  // Private functions ----------------

  /* Accept ETH during crowdsale (called by default function) */

  function buyTokens() private {
    uint ts = atNow();
    bool isPresale = false;
    bool isIco = false;
    uint tokens = 0;
    
    // minimum contribution
    require( msg.value >= MIN_CONTRIBUTION );
    
    // one address transfer hard cap
    require( icoEtherContributed[msg.sender].add(msg.value) <= MAX_CONTRIBUTION );

    // check dates for presale or ICO
    if (ts > DATE_PRESALE_START && ts < DATE_PRESALE_END) isPresale = true;  
    if (ts > DATE_ICO_START && ts < DATE_ICO_END) isIco = true;  
    require( isPresale || isIco );

    // presale cap in Ether
    if (isPresale) require( icoEtherReceived.add(msg.value) <= PRESALE_ETH_CAP );
    
    // get baseline number of tokens
    tokens = tokensPerEth.mul(msg.value) / 1 ether;
    
    // apply bonuses (none for last week)
    if (isPresale) {
      tokens = tokens.mul(100 + BONUS_PRESALE) / 100;
    } else if (ts < DATE_ICO_START + 7 days) {
      // first week ico bonus
      tokens = tokens.mul(100 + BONUS_ICO_WEEK_ONE) / 100;
    } else if (ts < DATE_ICO_START + 14 days) {
      // second week ico bonus
      tokens = tokens.mul(100 + BONUS_ICO_WEEK_TWO) / 100;
    }
    
    // ICO token volume cap
    require( tokensIssuedIco.add(tokens) <= TOKEN_SUPPLY_ICO );

    // register tokens
    balances[msg.sender]          = balances[msg.sender].add(tokens);
    icoTokensReceived[msg.sender] = icoTokensReceived[msg.sender].add(tokens);
    tokensIssuedIco               = tokensIssuedIco.add(tokens);
    tokensIssuedTotal             = tokensIssuedTotal.add(tokens);
    
    // register Ether
    icoEtherReceived                = icoEtherReceived.add(msg.value);
    icoEtherContributed[msg.sender] = icoEtherContributed[msg.sender].add(msg.value);
    

    // log token issuance
    Transfer(0x0, msg.sender, tokens);
    TokensIssued(msg.sender, tokens, balances[msg.sender], msg.value);

    // transfer Ether if we're over the threshold
    wallet.transfer(this.balance);
  }
  
  // ERC20 functions ------------------

  /* Override "transfer" (ERC20) */

  function transfer(address _to, uint _amount) public onlyOwner returns (bool success) {
      
      require( isTransferable() );
      if (balances[msg.sender] >= _amount && balances[_to] + _amount > balances[_to]) {
            balances[msg.sender] -= _amount;
            balances[_to] += _amount;
            
            super.transfer(_to, _amount);
            return true;
      }
      else {
            return false;
      }
      
  }
  
  /* Override "transferFrom" (ERC20) */

  function transferFrom(address _from, address _to, uint _amount) public onlyOwner returns (bool success) {    
    if (balances[_from] >= _amount && allowed[_from][msg.sender] >= _amount && balances[_to] + _amount > balances[_to]) {
            balances[_to] += _amount;
            balances[_from] -= _amount;
            allowed[_from][msg.sender] -= _amount;
            super.transferFrom(_from, _to, _amount);
            return true;
    }
    else {
        return false;
    }    
  }
  
}
