# nft-perp-trader


## Deployments

| Contract      |    Arbitrum                                                                                                                 |                                                              
|---------------|-------------------------------------------------------------------------------------------------------------------------|
| `NFTPerpOrder` | [`0x9f6459104Cf596a3012d7957F1698d6b17C2bBF1`](https://arbiscan.io/address/0x9f6459104Cf596a3012d7957F1698d6b17C2bBF1)
| `NFTPerpOrder Resolver`       | [`0xC55c1B19B74263727f2aa6a2c6f1BA0E15980BD0`](https://arbiscan.io/address/0xC55c1B19B74263727f2aa6a2c6f1BA0E15980BD0)
| `Fee Manager`         | [`0x4c5855d8156c9c326A68Db04bf7BBa2521BFBA2B`](https://arbiscan.io/address/0x4c5855d8156c9c326A68Db04bf7BBa2521BFBA2B) 

## Getting  Started 
```bash
# Clone repo
git clone https://github.com/0xNonso/nft-perp-trader.git
cd nft-perp-trader

# Checkout branch
git checkout feat/proxyless-account
```

## Test
Tests use [Foundry: Forge](https://github.com/gakonst/foundry)
```bash
# Install dependencies
forge install

# Run tests
forge test -vvvv
```

## Disclaimer

_These smart contracts are being provided as is. No guarantee, representation or warranty is being made, express or implied, as to the safety or correctness of the user interface or the smart contracts. They have not been audited and as such there can be no assurance they will work as intended, and users may experience delays, failures, errors, omissions, loss of transmitted information or loss of funds. The creators are not liable for any of the foregoing. Users should proceed with caution and use at their own risk._
