pragma solidity ^0.5.10;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../contracts/FlightSuretyData.sol";


/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract

    FlightSuretyData flightSuretyData;
    uint8 private constant MINIMUM_AIRLINES_TO_REGISTER = 4;
    uint256 public constant INSURANCE_PRICE = 1 ether;
    uint256 public constant PREMIUM = 10 ether;
 
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
         // Modify to call data contract's status
        require(flightSuretyData.isOperational(), "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    modifier requireSenderIsRegistered()
    {
         // Modify to call sender trying to register an airline is an already registered airline
        require(flightSuretyData.isRegistered(msg.sender), "Caller is not a registered airline");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    modifier requireSenderIsFunded()
    {
         // Modify to call sender trying to register an airline is an already funded airline
        require(flightSuretyData.isFunded(msg.sender), "Message sender is not a funded airline");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    modifier requireAirlineIsNotRegistered(address newAirlineAddress)
    {
         // Modify to call sender trying to register an airline is an already registered airline
        require(!flightSuretyData.isRegistered(newAirlineAddress), "Airline is already a registered airline");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    modifier requirePurchasedInsurance(address airline, string memory flightNumber, uint256 departureTime)
    {
         // Modify to call sender trying to register an airline is an already registered airline
        require(!flightSuretyData.insPurchaseStatus(getInsuranceContractKey
        (airline, flightNumber, departureTime, msg.sender)), "Insurance already registered");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    modifier requireMaximumPremium(uint256 insuranceAmount)
    {
        require(insuranceAmount <= 1 ether, "Insurance has to be 1 ether");
        _;
    }
    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireSufficientAmount()
    {
        require(msg.value >= 0, "Msg value not greater than 0");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor
                                (
                                    address payable datacontract
                                )
                                public
    {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(datacontract);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational()
                            public
                            view
                            returns(bool)
    {
        return flightSuretyData.isOperational();  // Modify to call data contract's status
    }

    function isRegistered(address addressOfAirline)
                            public
                            view
                            returns(bool)
    {
        return flightSuretyData.isRegistered(addressOfAirline);  // Modify to call data contract's status
    }

    function isFunded(address addressOfAirline)
                            public
                            view
                            returns(bool)
    {
        return flightSuretyData.isFunded(addressOfAirline);  // Modify to call data contract's status
    }

    function alreadySubmitted(airAddress);(address addressOfAirline)
                            public
                            view
                            returns(bool)
    {
        return flightSuretyData.alreadySubmitted(airAddress);(addressOfAirline);  // Modify to call data contract's status
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  

   function registerAirline(airAddress, airName, isRegisteredBool);
                            (   address newAirlineAddress,
                                string calldata airlineName
                            )
                            external
                            requireIsOperational
                            requireSenderIsRegistered
                            requireSenderIsFunded
                            requireAirlineIsNotRegistered(newAirlineAddress)
                            returns(bool success)
    {
        require(newAirlineAddress != address(0), "'addressOfAirline' must be a valid address.");
        
        bool isSubmittedButNotYetRegistered = flightSuretyData.alreadySubmitted(airAddress);(newAirlineAddress);
        uint256 regAirCount = flightSuretyData.regAirCount();
        uint256 numAirlineVotes = flightSuretyData.airVoteCount(newAirlineAddress);

        if(regAirCount < MINIMUM_AIRLINES_TO_REGISTER){
            
            flightSuretyData.registerAirline(airAddress, airName, isRegisteredBool);(newAirlineAddress, airlineName, true);
        
        } else { 
            
            if(isSubmittedButNotYetRegistered){

                if(!flightSuretyData.voteStatus(newAirlineAddress, msg.sender)){
                    numAirlineVotes++;
                    this.airlineMultiSig(newAirlineAddress, numAirlineVotes);
                }

                if(numAirlineVotes >= regAirCount.div(2) ){
                    
                    flightSuretyData.regQueuedAirline(newAirlineAddress);

                } else {
                    return false;
                }
            } else {

                flightSuretyData.registerAirline(airAddress, airName, isRegisteredBool);(newAirlineAddress, airlineName, false);
                return false;
            }
        }
    }

    function airlineMultiSig(address addressOfAirline, uint256 updatedNumVotes) 
                            external
                            requireIsOperational
                            requireSenderIsRegistered
                            returns(bool)
    {
        flightSuretyData.airlineMultiSig(addressOfAirline, updatedNumVotes);

        uint256 regAirCount = flightSuretyData.regAirCount();
        
        if(updatedNumVotes >= regAirCount.div(2)){
            flightSuretyData.regQueuedAirline(addressOfAirline);
            return true;
        } else {
            return false;
        }
    }
   

   /**
    * @dev Register a future flight for insuring.
    *
    */  
    function regFlight
                                (
                                    string calldata flightNumber,
                                    uint256 departureTime
                                )
                                external
                                requireIsOperational
                                requireSenderIsRegistered // airline is msg.sender
                                requireSenderIsFunded
    {
        bytes32 flightKey = getFlightKey(msg.sender, flightNumber, departureTime);

        flightSuretyData.regFlight(msg.sender, flightNumber, departureTime, flightKey);
    }
    
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus
                                (
                                    address airline,
                                    string memory flight,
                                    uint256 timestamp,
                                    uint8 statusCode
                                )
                                internal
    {

        flightSuretyData.processFlightStatus(airline, flight, timestamp, statusCode);

        if (statusCode == STATUS_CODE_LATE_AIRLINE){

            flightSuretyData.creditInsurees(airline, flight, timestamp);
        
        }

    }

    function fundAirlineAndRegisterInitialFlights
                                (
                                    string memory flight1,
                                    uint256 timestamp1,    // departure time
                                    string memory flight2,
                                    uint256 timestamp2,  
                                    string memory flight3,
                                    uint256 timestamp3 
                                )
                                public
                                payable
    {
        bytes32 flightKey1 = getFlightKey(msg.sender, flight1, timestamp1);
        bytes32 flightKey2 = getFlightKey(msg.sender, flight2, timestamp2);
        bytes32 flightKey3 = getFlightKey(msg.sender, flight3, timestamp3);

        flightSuretyData.fundInitAirline(msg.sender, msg.value);
        flightSuretyData.regFlight(msg.sender, flight1, timestamp1, flightKey1);
        flightSuretyData.regFlight(msg.sender, flight2, timestamp2, flightKey2);
        flightSuretyData.regFlight(msg.sender, flight3, timestamp3, flightKey3);       
    }

    function fund
                            (  
                            )
                            public
                            payable
                            requireIsOperational
                            requireSufficientAmount
                            returns(bool)
    {   
        flightSuretyData.fund();
    }

    function withdrawDividends
                            (  
                            )
                            public
                            payable
                            requireIsOperational
                            returns(bool)
    {   
        flightSuretyData.pay(msg.sender);
    }

    /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (   
                                address airline,
                                string calldata flightNumber,
                                uint256 departureTime,   
                                uint256 insuranceAmount                            
                            )
                            external
                            payable
                            requireIsOperational
                            requireSufficientAmount
                            requirePurchasedInsurance(airline, flightNumber, departureTime)
                            requireMinimumAmount(insuranceAmount)
    {
        uint256 payoutAmount = (insuranceAmount.mul(3)).div(2);

        flightSuretyData.buy(airline, flightNumber, departureTime, msg.sender, insuranceAmount, payoutAmount);   // msg.sender is passenger
    }

    // Generate a request for oracles to fetch flight information
    // Intended to be triggered from the UI
    function fetchFlightStatus
                        (
                            address airline,
                            string calldata flight,
                            uint256 timestamp                            
                        )
                        external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    } 


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3] memory)
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string calldata flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
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

    function getInsuranceContractKey
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

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3] memory)
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

}   

// REFERENCE
//=> https://github.com/zeil156/FlightSurety