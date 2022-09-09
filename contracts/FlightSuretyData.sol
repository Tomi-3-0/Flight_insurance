pragma solidity ^0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FlightSuretyData.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    uint256 private availableFunds = 0;
    uint256 public numberOfRegisteredAirlines;

    //Flight Status Codes
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    //mappings
    mapping(address => uint256) private authorizedContracts;
    mapping(bytes32 => Flight) private flights;
    mapping(address => Airline) private airlines;
    mapping(address => Passenger) private passengers;
    mapping(bytes32 => InsuranceContract) private insuranceContracts;

    struct Airline {
        address airAddress;
        string airlineName;
        bool isSubmitted;
        bool isRegistered;
        bool isFunded;
        uint256 fundingAmt;
        uint256 voteAmt;
        mapping(address => bool) voters;
    }

    struct Flight {
        string flightNum;
        bool isRegistered;
        uint8 statusCode;
        uint256 departTime;
        address airline;
        bytes32[] writtenContracts;
        uint256 numContracts;
        uint256 riskAmt;
    }
   
    struct InsuranceContract {
        address airAddress;
        string flightNum;
        uint256 departTime;
        uint256 insuranceAmt;
        address passengerAddress;
        bool isPaid;
        uint256 payAmt;
        bool isActive;
    }
   
    struct Passenger {
        address passengerAddress;
        uint256 creditAmount;
        bool exists;
    }
    

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        authorizedContracts[msg.sender] = 1;
        operational = true;

        airlines[msg.sender].airlineAddress = msg.sender;
        airlines[msg.sender].airlineName = "Initial Air";
        airlines[msg.sender].isSubmitted = true;
        airlines[msg.sender].isRegistered = true;
        airlines[msg.sender].isFunded = false;
        airlines[msg.sender].fundingAmt = 0;
        airlines[msg.sender].voteAmt = 0;

        numberOfRegisteredAirlines = 1;

    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireMinPremium()
    {
        require(msg.value >= 0, "Msg value not greater than 0");
        _;
    }

    modifier requireEnoughBalance(address airline, string memory flight, uint256 timestamp)
    {
        require((availableFunds - (flights[getFlightKey(airline, flight, timestamp)].riskAmt) >= 0), "Not enough funds");
        _;
    }

    // ADD NOTPAID MODIFIER LIKE IN ROW 108 OF Eamon??
    // {
    //     require(, "");
    //     _;
    // }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }

    function isRegistered(address airAddress)
                            public
                            view
                            returns(bool)
    {
        return airlines[airAddress].isRegistered;
    }
    
    function isSubmitted(address airAddress)
                            public
                            view
                            returns(bool)
    {
        return airlines[airAddress].isSubmitted;
    }
    
    function isFunded(address airAddress)
                            public
                            view
                            returns(bool)
    {
        return airlines[airAddress].isFunded;
    }

    function alreadyQueued(address airAddress)
                            public
                            view
                            returns(bool)
    {
        return airlines[airAddress].isSubmitted;
    }

    function regAirCounter()
                            public
                            view
                            returns(uint256)
    {
        return numberOfRegisteredAirlines;
    }

    function airVoteCounter(address airAddress)
                            public
                            view
                            returns(uint256) {
        return airlines[airAddress].voteAmt;
    }

    function voteStatus(address airAddress, address msgSender)
                            public
                            view
                            returns(bool) {
        if(!airlines[airAddress].voters[msg.sender]) {
            return false;
        } else {
            return true;
        }        
    }
    
    function regFlightStatus(address airline, string memory flight, uint256 timestamp)
                            public
                            view
                            returns(bool) {
        
        return (flights[getFlightKey(airline, flight, timestamp)].isRegistered);
    }
    
    function insurancePurchaseStatus(bytes32 insuranceContractKey)
                            public
                            view
                            returns(bool)
    {
        return insuranceContracts[insuranceContractKey].isActive;                        
    }
  
    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    function authCaller(address addressToAuth) external requireContractOwner {
        authorizedContracts[addressToAuth] = 1;
    }

    function deauthCaller(address addressToAuth) external requireContractOwner {
        delete authorizedContracts[addressToAuth];
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    
    function registerAirline
                            (
                                address airAddress,
                                string  airName,
                                bool isRegisteredBool
                            )
                            external
                            requireIsOperational
    {
    
        require(!airlines[airAddress].isRegistered, "Airline already registered.");

        airlines[airAddress] = Airline({
                                                airAddress: airAddress,
                                                airName: airName,
                                                isSubmitted: true,
                                                isRegistered: isRegisteredBool,
                                                isFunded: false,
                                                fundingAmt: 0,
                                                voteAmt: 1       
                                            });

        if(isRegisteredBool) {
            numberOfRegisteredAirlines++;
        }
    }


    /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight
                                (
                                    address airAddress,
                                    string flightNum,
                                    uint256 departureTime,
                                    bytes32 flightKey
                                )
                                requireIsOperational
                                external
    {

        require(flights[flightKey].isRegistered == false, "This flight is already registered");
        

        flights[flightKey].flightNum = flightNum;
        flights[flightKey].isRegistered = true;
        flights[flightKey].statusCode = STATUS_CODE_UNKNOWN;
        flights[flightKey].departTime = departureTime;
        flights[flightKey].numContracts = 0;
        flights[flightKey].airline = airAddress;
        flights[flightKey].riskAmt = 0;
    }

   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (
                                address airline,
                                string flightNum,
                                uint256 departTime,
                                address passenger,
                                uint256 insuranceAmt,
                                uint256 payout
                            )
                            external
                            payable
                            returns(uint256)
    {
        bytes32 insuranceContractKey = getInsContractKey(airline, flightNum, departTime, passenger);    // msg.sender is passenger
        bytes32 flightKey = getFlightKey(airline, flightNum, departTime);

        
        insuranceContracts[insuranceContractKey] = InsuranceContract ({
                                                airAddress: airline,
                                                flightNum: flightNum,
                                                departTime: departTime,
                                                insuranceAmt: insuranceAmt,
                                                passengerAddress: passenger,
                                                isPaid: false,
                                                payAmt: payout,
                                                isActive: true
                                        });

        uint256 updatedNumContracts = flights[flightKey].numContracts + 1;
        flights[flightKey].writtenContracts[updatedNumContracts] = insuranceContractKey;
        flights[flightKey].numContracts = updatedNumContracts;

        uint256 currentLiability = flights[flightKey].riskAmt;
        flights[flightKey].riskAmt = currentLiability + payout;

        availableFunds = availableFunds + msg.value;
        contractOwner.transfer(msg.value);
        return updatedNumContracts;
    }


    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                    address airline,
                                    string flight,
                                    uint256 timestamp
                                )
                                external
                                requireEnoughBalance(airline, flight, timestamp)
    {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);

        for (uint256 i = 0; i < flights[flightKey].writtenContracts.length; i++) {
            bytes32 insuranceContractKey = flights[flightKey].writtenContracts[i];

            address _passengerAddress = insuranceContracts[insuranceContractKey].passengerAddress;
            uint256 _payAmt = insuranceContracts[insuranceContractKey].payAmt;

            insuranceContracts[insuranceContractKey].isPaid = true;

            if(passengers[_passengerAddress].exists){

                uint256 updatedCreditAmount = passengers[_passengerAddress].creditAmount + _payAmt;
                passengers[_passengerAddress].creditAmount = updatedCreditAmount;
            } else {

                passengers[_passengerAddress] = Passenger({
                                                passengerAddress: _passengerAddress,
                                                creditAmount: _payAmt,
                                                exists: true
                                        });

            } 

            availableFunds = availableFunds - _payAmt;
        }
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                                address  passengerAddress 
                            )
                            external
                            payable
                            requireIsOperational
    {
        uint256 payment = passengers[passengerAddress].creditAmount;

        require(payment <= availableFunds, "Not enough funds for payout");

        passengerAddress.transfer(payment);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (   
                            )
                            public
                            payable
                            requireIsOperational
                            requireMinPremium
                            returns(bool)
    {
        uint256 currentFunds = airlines[msg.sender].fundingAmt;
        uint256 newFundingAmt = currentFunds.add(msg.value);
        airlines[msg.sender].fundingAmt = newFundingAmt;
        availableFunds = availableFunds + msg.value;
        contractOwner.transfer(msg.value);
            //refund excess ether
        if(newFundingAmt >= 10 ether){
            airlines[msg.sender].isFunded = true;
            return true;
        } else {
            return false;
        }
    }

    function fundInitAirline
                        (
                            address airAddress,
                            uint256 initialFunding
                        )
                        public
                        payable
                        requireIsOperational
                        requireMinPremium
                        returns(bool)
    {
        uint256 currentFunds = airlines[airAddress].fundingAmt;
        uint256 newFundingAmt = currentFunds.add(initialFunding);
        airlines[airAddress].fundingAmt = newFundingAmt;
        availableFunds = availableFunds + initialFunding;
        contractOwner.transfer(initialFunding);

        if(newFundingAmt >= 10 ether){
            airlines[airAddress].isFunded = true;
            return true;
        } else {
            return false;
        }    
    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    function getFlightKeyTest
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        pure
                        external
                        returns(bytes32)
    {
        return getFlightKey(airline, flight, timestamp);
    }

    function processFlightStatus
                                (
                                    address airline,
                                    string flightNum,
                                    uint256 timestamp,
                                    uint8 updatedStatusCode
                                )
                                requireIsOperational
                                external
    {
        flights[getFlightKey(airline, flightNum, timestamp)].statusCode = updatedStatusCode;
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable
                            
    {
        fund();
    }

    /**
    * @dev check if airline is registered
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function checkAirReg(address checkAirline) external view requireIsOperational  returns(bool) {
        return airlines[checkAirline].isRegistered;
    }

    function regSubmittedAirline(address airlineAddress) 
                            external
                            requireIsOperational
                            returns(bool)
    {
        airlines[airlineAddress].isRegistered = true;
        numberOfRegisteredAirlines++;
        return true;
    }

    function voteForAirReg(address airlineAddress, uint256 updatedVoteAmt) 
                            external
                            requireIsOperational
    {
        airlines[airlineAddress].voters[msg.sender] = true;
        airlines[airlineAddress].voteAmt = updatedVoteAmt;
    }

    function getInsContractKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp,
                            address passenger
                        )
                        pure
                        internal
                        returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp, passenger));
    }

    function unregisterAirline
                        (
                            address airline
                        )
                        external
    {
        airlines[airline] = Airline({
                                                airAddress: address(0),
                                                airName: '',
                                                isSubmitted: false,
                                                isRegistered: false,
                                                isFunded: false,
                                                fundingAmt: 0,
                                                voteAmt: 0
                                        });

        
    }
}
// REFERENCE
//=> https://github.com/zeil156/FlightSurety