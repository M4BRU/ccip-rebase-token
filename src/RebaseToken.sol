// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RebaseToken
 * @author Lucas Mabru-Colson
 * @notice the interest rate in the smart contract can only decrease
 * @notice Each user will have their own interest rate that is the global interest rate at the time they deposit eth
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    uint256 private constant PRECISION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private s_interestRate = 5e10;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    event InterestRateSet(uint256 newInterestRate);

    
    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender){

    }

    function grandMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
     * 
     * @param _newInterestRate  the new interest rate to set
     * @dev the interest rate can only decrease
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner{
        if(_newInterestRate < s_interestRate){
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    function principleBalanceOf(address _user) external view returns (uint256){
        return super.balanceOf(_user);
    }

    /**
     * @param _amount amount to mint
     */
    function mint(address _to, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE){
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    /**
     * @notice burn the user tokens when they withdras fro mthe vault
     * @param _from  the user to burn thher tokens from
     * @param _amount the amount of tokens to burn
     */
    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE){
        if(_amount == type(uint256).max){//to avoid dust
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /**
     * calculate the balance + interst rate accumulated since the last update
     * @param _user the user to calculate the balance for
     */
    function balanceOf(address _user) public view override returns(uint256){
        return super.balanceOf(_user) * _calculateUserAccuulatedInterstSinceLastUpdate(_user) / PRECISION_FACTOR;
    }

    /**
     * @notice transfer tokens from one user to another
     * @param _recipient the user to transfer the tokesn to
     * @param _amount the amouint of tokens to transfer
     */
    function transfer(address _recipient, uint256 _amount) public override returns (bool){
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);
        if(_amount == type(uint256).max){
            _amount = balanceOf(msg.sender);
        }
        if(balanceOf(_recipient) == 0){
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    /**
     * @notice transfer tokens from one user to another
     * @param _sender the user to transfer trhe tokens from
     * @param _recipient the user to transfer the tokesn to
     * @param _amount the amouint of tokens to transfer
     */
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);
        if(_amount == type(uint256).max){
            _amount = balanceOf(_sender);
        }
        if(balanceOf(_recipient) == 0){
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }
        return super.transfer(_recipient, _amount);
    }

    function _calculateUserAccuulatedInterstSinceLastUpdate(address _user) internal view returns(uint256 linearInterest){
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearInterest = PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed);
    }

    /**
     * 
     * @notice mint the axxrued interest to the user since the last time they interacted with the protocol
     * @param _user the user to mint the accrued interest to
     */
    function _mintAccruedInterest(address _user) internal {
        
        uint256 previousPrincipleBalance = super.balanceOf(_user);
        uint256 currentBalance = balanceOf(_user);
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;



        s_userLastUpdatedTimestamp[_user] = block.timestamp;

        _mint(_user, balanceIncrease);
    }

    /**
     * @notice get the current interest rate set on the contract
     * @return the interest rate of the contract
     */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    /**
     * 
     * @param _user the user to get interest rate for
     */
    function getUserInterestRate(address _user) external view  returns(uint256) {
        return s_userInterestRate[_user];
    }

}