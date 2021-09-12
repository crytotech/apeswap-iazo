# IAZO - "Initial Ape Zone Offering"
![tests](https://github.com/ApeSwapFinance/apeswap-iazo/actions/workflows/CI/badge.svg)
  
* [IAZO Test Coverage](coverage/index.html)
* [IAZO Documentation](docs/)

IAZOs are self serve initial token offering contracts. New tokens that have yet to be released in circulation can be put up for sale with these contracts. If the sale is successful, then an APE-LP liquidity pair is automatically created on the ApeSwap DEX. A portion of the proceeds are put into liquidity and locked in a vesting contract while the creator of the IAZO is sent the rest. 

## Tools

Truffle Framework:
- Compile contracts
  - solc/network config: [truffle-config.js](truffle-config.js)
- Deploy contracts to: 
  - BSC
  - BSC Testnet
  - Development `8545` (run dev chain with: `npx ganache-cli`)

Open Zeppelin
- Base contract imports
- Test environment 
- Test helpers 


## Env Vars
To deploy and verify contracts environment variables must be set in a `.env` file. See [.env.example](.env.example) for a list of relevant variables.




## Compile
`yarn compile`

## Deploy Contracts

`yarn migrate:bsc`   
`yarn migrate:bsc-testnet`   
`yarn migrate:dev`   

## Verify

`yarn verify:bsc`
`yarn verify:bsc-testnet`

## Test and Coverage
To run tests written in the [test](test/) dir, run:  
`yarn test`  

A coverage tool is provided with a nice UI output:   
`yarn coverage`  

Find the coverage output here: [coverage report](coverage/index.html)


## Docs 
`solidity-docgen` is used to provide markdown docs generated from comments in the solidity contracts.  

To generate/update the docs run:  
`yarn gen:docs`  

Find the docs here: [IAZO Docs](docs/)