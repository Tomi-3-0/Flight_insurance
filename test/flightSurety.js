var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async(accounts) => {

    var config;
    before('setup contract', async() => {
        config = await Test.Config(accounts);
        await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
    });

    /****************************************************************************************/
    /* Operations and Settings                                                              */
    /****************************************************************************************/

    it(`(multiparty) has correct initial isOperational() value`, async function() {

        // Get operating status
        let status = await config.flightSuretyData.isOperational.call();
        assert.equal(status, true, "Incorrect initial operating status value");

    });

    it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function() {

        // Ensure that access is denied for non-Contract Owner account
        let accessDenied = false;
        try {
            await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
        } catch (e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, true, "Access not restricted to Contract Owner");

    });

    it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function() {

        // Ensure that access is allowed for Contract Owner account
        let accessDenied = false;
        try {
            await config.flightSuretyData.setOperatingStatus(false);
        } catch (e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, false, "Access not restricted to Contract Owner");

    });

    it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function() {

        await config.flightSuretyData.setOperatingStatus(false);

        let reverted = false;
        try {
            await config.flightSurety.setTestingMode(true);
        } catch (e) {
            reverted = true;
        }
        assert.equal(reverted, true, "Access not blocked for requireIsOperational");

        // Set it back for other tests to work
        await config.flightSuretyData.setOperatingStatus(true);

    });

    it('(airline) cannot register an Airline using registerAirline() if it is not funded', async() => {

        // ARRANGE
        let newAirline = accounts[2];

        // ACT
        try {
            await config.flightSuretyApp.registerAirline(newAirline, { from: config.firstAirline });
        } catch (e) {

        }
        let result = await config.flightSuretyData.isAirline.call(newAirline);

        // ASSERT
        assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

    });

    it(`(First Airline) is account[0] and is registered when contract is deployed`, async function() {
        // Determine if Airline is registered
        let result = await config.flightSuretyData.isRegistered.call(accounts[0]);
        assert.equal(result, true, "First airline was not account[0] that was registed upon contract creation");
    });

    it('only registered airline may register a new airline to a maximum of four', async() => {


        try {
            await config.flightSuretyData.fund({ from: accounts[0], value: web3.utils.toWei('10', "ether") });

            await config.flightSuretyApp.registerAirline(accounts[1], "newairline2", { from: accounts[0] }); // initial airline (contract owner) is the first registered airline
            await config.flightSuretyApp.registerAirline(accounts[2], "newairline3", { from: accounts[0] });

            await config.flightSuretyData.fund({ from: accounts[1], value: web3.utils.toWei('10', "ether") });
            await config.flightSuretyData.fund({ from: accounts[2], value: web3.utils.toWei('10', "ether") });

            await config.flightSuretyApp.registerAirline(accounts[3], "newairline4", { from: accounts[1] });
        } catch (e) {
            console.log(e);
        }

        let result = await config.flightSuretyData.isRegistered.call(accounts[3]);

        // ASSERT
        assert.equal(result, true, "Only registered airline can register a new flight");
    });

    it('multi-sig restriction for fifth airline', async() => {

        // ARRANGE
        await config.flightSuretyData.unregisterAirline(accounts[1]);
        await config.flightSuretyData.unregisterAirline(accounts[2]);
        await config.flightSuretyData.unregisterAirline(accounts[3]);

        // ACT
        try {
            await config.flightSuretyApp.registerAirline(accounts[1], "newairline2", { from: accounts[0] }); // initial airline (contract owner) is the first registered airline
            await config.flightSuretyApp.registerAirline(accounts[2], "newairline3", { from: accounts[0] });
            await config.flightSuretyApp.registerAirline(accounts[3], "newairline4", { from: accounts[0] });

            await config.flightSuretyApp.voteForAirReg(accounts[3], 1, { from: accounts[0] });

            await config.flightSuretyApp.registerAirline(accounts[4], "newairline5", { from: accounts[0] });
        } catch (e) {
            console.log(e);
        }

        let result = await config.flightSuretyData.isRegistered.call(accounts[4]);

        // ASSERT
        assert.equal(result, false, "Should not be able to register a fifth airline without multi-sig");
    });

    it('only register the fifth airline after multi-sig reached', async() => {

        // ARRANGE
        await config.flightSuretyData.unregisterAirline(accounts[1]);
        await config.flightSuretyData.unregisterAirline(accounts[2]);
        await config.flightSuretyData.unregisterAirline(accounts[3]);
        await config.flightSuretyData.unregisterAirline(accounts[4]);

        // ACT
        try {
            await config.flightSuretyApp.registerAirline(accounts[1], "newairline2", { from: accounts[0] }); // initial airline (contract owner) is the first registered airline
            await config.flightSuretyApp.registerAirline(accounts[2], "newairline3", { from: accounts[0] });
            await config.flightSuretyApp.registerAirline(accounts[3], "newairline4", { from: accounts[0] });

            await config.flightSuretyApp.voteForAirReg(accounts[4], 1, { from: accounts[0] });
            await config.flightSuretyApp.voteForAirReg(accounts[4], 2, { from: accounts[0] });

            await config.flightSuretyApp.registerAirline(accounts[4], "newairline5", { from: accounts[0] });
        } catch (e) {
            console.log(e);
        }

        let result = await config.flightSuretyData.isRegistered.call(accounts[4]);

        // ASSERT
        assert.equal(result, true, "Should be able to register a fifth airline when multi-party consensus is reached prior to the request to register");
    });



    it('airline is registered, cannot participate but is queued', async() => {

        // ARRANGE
        let flightTimestamp = Math.floor(Date.now() / 1000);

        // ACT
        try {
            await config.flightSuretyApp.regFlight('KLM546', flightTimestamp, { from: accounts[6] });
        } catch (e) {
            console.log(e);
        }

        let result = await config.flightSuretyData.regFlightStatus.call(accounts[6], 'KLM546', 1642658304);

        // ASSERT
        assert.equal(result, false, "Should not be able to participate in contract if not funded");
    });


    it('register an airline after premium is paid', async() => {

        await config.flightSuretyApp.regFlight('KLM975', flightTimestamp, { from: accounts[6] });
        await config.flightSuretyData.fund({ from: accounts[6], value: web3.utils.toWei('10', "ether") });
        await config.flightSuretyData.isQueued.call(accounts[6]);

        await config.flightSuretyData.isQueued.call(accounts[6]);
        let flightTimestamp = Math.floor(Date.now() / 1000);


        let result = await config.flightSuretyData.regFlightStatus.call(accounts[6], 'KLM975', flightTimestamp);

        // ASSERT
        assert.equal(result, true, "Should be able to register a flight after premium is paid");
    });


});