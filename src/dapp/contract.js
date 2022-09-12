import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import { call } from 'file-loader';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.initialize(callback);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {

            this.owner = accts[0];

            let counter = 1;

            while (this.airlines.length < 5) {
                this.airlines.push(accts[counter++]);
            }

            while (this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }

            callback();
        });
    }

    isOperational(callback) {
        let self = this;
        self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner }, callback);
    }

    fetchFlightStatus(flight, callback) {
        let self = this;
        let payload = {
            airline: self.airlines[0],
            flight: flight,
            timestamp: Math.floor(Date.now() / 1000)
        }
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner }, (error, result) => {
                callback(error, payload);
            });
    }

    registerFlashipFlights(callback) {
        let self = this;

        let payload = {
            flight1: 'KLM456',
            flight2: 'KLM945',
            flight3: 'KLM888',
            timestamp1: Math.floor(this.flighttimestamp1.getTime() / 1000),
            timestamp2: Math.floor(this.flighttimestamp2.getTime() / 1000),
            timestamp3: Math.floor(this.flighttimestamp3.getTime() / 1000)
        }
        self.flightSuretyApp.methods
            .fundAirlineAndRegisterFlights(
                payload.flight1, payload.timestamp1,
                payload.flight2, payload.timestamp2,
                payload.flight3, payload.timestamp3
            ).send({
                from: self.owner,
                value: this.web3.utils.toWei('10', 'ether'),
            }, (error, result) => {
                callback(error, payload);
            })
    }

    buy(flightNumber, callback) {
        let self = this;

        let payload = {
            airline: '',
            flightNumber: '',
            departureTime: Math.floor(Date.now() / 1000),
            insuranceAmount: this.web3.utils.toWei('1', "ether")
        }

        if (flightNumber == "KLM456") {
            payload.airline = this.owner;
            payload.flightNumber = "KLM456";
            payload.departureTime = Math.floor(this.flighttimestamp1.getTime() / 1000);
        } else if (flightNumber == "KLM945") {
            payload.airline = this.owner;
            payload.flightNumber = "KLM945";
            payload.departureTime = Math.floor(this.flighttimestamp2.getTime() / 1000);
        } else if (flightNumber == "KLM888") {
            payload.airline = this.owner;
            payload.flightNumber = "KLM888";
            payload.departureTime = Math.floor(this.flighttimestamp3.getTime() / 1000);
        }

        self.flightSuretyApp.methods
            .buy(payload.airline, payload.flightNumber, payload.departureTime, payload.insuranceAmount)
            .send({ from: this.owner }, (error, result) => {
                callback(error, payload);
            });
    }

    withdrawDividends(callback) {
        let self = this;
        let payload = {}
        self.flightSuretyApp.methods
            .withdrawDividends().send({ from: self.owner }, (error, result) => {
                callback(error, payload);
            });
    }
}