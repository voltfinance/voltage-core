# Voltage Deployment

1) Install dependencies in both this repo and the periphery repo:
```
$ yarn install
```

2) Copy private key that contains xDAI into this repo and the the periphery repo's `truffle-config.js` where specified.

### In the voltage-v2-core repo

3) Update the `FEE_TO_SETTER_ADDRESS` in the `migrations/2_deploy.js` file if required.

4) Deploy to xDAI:
```
$ npx truffle migrate --network fuse
```

5) Get the `init code hash`:
```
$ npx truffle exec scripts/getUniswapV2PairBytecode.js
```

### In the voltage-v2-periphery repo

6) Copy the previously output `VoltageFactory` address to the `FACTORY_ADDRESS` in the `migrations/2_deploy.js` file.

7) Update the `WRAPPED_ETH` address in the `migrations/2_deploy.js` file if required.

8) Copy the `init code hash` previously output to `contracts/libraries/VoltageLibrary.sol` at line 24.

9) Deploy to xDAI:
```
$ npx truffle migrate --network xdai
```

Note it seems xdai doesn't currently impose the contract size limit of 24576 bytes so we can enable 10000 optimizer runs
making individual transaction executions cheaper. There's a chance xdai will introduce the limit in future in which
case the current optimizer runs will need to be reduced. The current size of the UniswapV2Router02 is 26887 bytes.
