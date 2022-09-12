import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {

    let result = null;

    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            console.log(error, result);
            display('Operational Status', 'Check if contract is operational', [{
                label: 'Operational Status',
                error: error,
                value: result
            }]);
        });


        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flight = DOM.elid('flight-number').value;
            // Write transaction
            contract.fetchFlightStatus(flight, (error, result) => {
                display('Oracles', 'Trigger oracles', [{
                    label: 'Fetch Flight Status',
                    error: error,
                    value: result.flight + ' ' + result.timestamp
                }]);
            });
        })

        DOM.elid('buy-insurance').addEventListener('click', () => {
            let flight = DOM.elid('availableFlights').value;
            //write transaction
            contract.buy(flight, (error, result) => {
                display('Flights', 'Insurance bought', [{
                    label: 'Buy Insurance for this flight',
                    error: error,
                    value: (result.insuranceAmount) + 'ether paid'
                }]);
            });
        })

        DOM.elid('register-flights').addEventListener('click', () => {
            let flight = DOM.elid('');
            contract.registerFlagshipFlights(flight, (error, result) => {
                display('Flight registered', [{
                    label: 'Registered flight: ',
                    error: error,
                    value: result.flight1 + "," +
                        result.flight2 + "," +
                        result.flight3
                }]);
            });
        })
        DOM.elid('withdraw-dividends').addEventListener('click', () => {
            //write transactions
            contract.withdrawDividends((error, result) => {
                display('Payouts', 'Payouts to withdraw', [{
                    label: 'Withdraw dividends',
                    error: error,
                    value: result
                }]);
            });
        })

    });


})();


function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({ className: 'row' }));
        row.appendChild(DOM.div({ className: 'col-sm-4 field' }, result.label));
        row.appendChild(DOM.div({ className: 'col-sm-8 field-value' }, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}