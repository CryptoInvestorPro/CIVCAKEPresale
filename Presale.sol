// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./libs/IBEP20.sol";
import "./libs/SafeBEP20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Presale is ReentrancyGuard {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;
    // Maps user to the number of tokens owned
    mapping (address => uint256) public tokensOwned;
    // The number of unclaimed tokens the user has
    mapping (address => uint256) public tokensUnclaimed;

    // CIVCAKE token
    IBEP20 CIVCAKE;
    // Sale active
    bool isSaleActive;
    // Claim active
    bool isClaimActive;
    // Starting timestamp normal
    uint256 startingTimeStamp;
    uint256 totalTokensSold = 0;
    uint256 busdPerToken = 3;
    uint256 busdReceived = 0;
    //cap on the total BUSD value recieved
    uint256 presaleCap = 300000 ether;
    // BUSD token
    IBEP20 BUSD;

    address payable owner;

    modifier onlyOwner(){
        require(msg.sender == owner, "This operation can only be done by the owner");
        _;
    }

    event TokenBuy(address user, uint256 tokens);
    event TokenClaim(address user, uint256 tokens);

    constructor (address _CIVCAKE, address _BUSD, uint256 _startingTimestamp) public {
        CIVCAKE = IBEP20(_CIVCAKE);
        BUSD = IBEP20(_BUSD);
        isSaleActive = true;
        owner = msg.sender;
        startingTimeStamp = _startingTimestamp;
    }

    function buy (uint256 _amount, address beneficiary) public nonReentrant {
        require(isSaleActive, "Presale has ended");
        address _buyer = beneficiary;
        uint256 tokens = _amount.div(busdPerToken);
        require (busdReceived +  _amount <= presaleCap, "We have hit the presale cap");
        require(block.timestamp >= startingTimeStamp, "Presale hasn't started yet");

        BUSD.safeTransferFrom(beneficiary, address(this), _amount);

        tokensOwned[_buyer] = tokensOwned[_buyer].add(tokens);
        tokensUnclaimed[_buyer] = tokensUnclaimed[_buyer].add(tokens);
        totalTokensSold = totalTokensSold.add(tokens);
        busdReceived = busdReceived.add(_amount);
        emit TokenBuy(beneficiary, tokens);
    }

    function setSaleActive(bool _isSaleActive) external onlyOwner {
        isSaleActive = _isSaleActive;
    }

    function setClaimActive(bool _isClaimActive) external onlyOwner {
        isClaimActive = _isClaimActive;
    }

    function getTokensOwned () external view returns (uint256) {
        return tokensOwned[msg.sender];
    }

    function getTokensUnclaimed () external view returns (uint256) {
        return tokensUnclaimed[msg.sender];
    }

    function getCIVCAKETokensLeft () external view returns (uint256) {
        return CIVCAKE.balanceOf(address(this));
    }

    function claimTokens (address claimer) external {
        require (isClaimActive, "Claim is not active yet");
        require (tokensOwned[msg.sender] > 0, "You don't have any CIVCAKE tokens");
        require (CIVCAKE.balanceOf(address(this)) >= tokensOwned[msg.sender], "Insufficient CIVCAKE tokens to transfer");
        require (tokensUnclaimed[msg.sender] > 0, "You don't have any unclaimed CIVCAKE tokens");

        tokensUnclaimed[msg.sender] = tokensUnclaimed[msg.sender].sub(tokensOwned[msg.sender]);

        CIVCAKE.safeTransfer(msg.sender, tokensOwned[msg.sender]);
        emit TokenClaim(msg.sender, tokensOwned[msg.sender]);
    }

    function withdrawFunds () external onlyOwner {
        BUSD.safeTransfer(msg.sender, BUSD.balanceOf(address(this)));
    }

    function withdrawUnsoldCIVCAKE() external onlyOwner {
        uint256 amount = CIVCAKE.balanceOf(address(this)) - totalTokensSold;
        CIVCAKE.safeTransfer(msg.sender, amount);
    }
}