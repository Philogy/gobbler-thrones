# Just Gobbler Things
While this repo initially only housed my "Gobbler Thrones" project over time I've added a small
range of Art Gobbler related utility contracts.

## [GOO-Sitter](./src/GooSitter.sol)
A custody contract that holds Gobblers & GOO on your behalf, allowing you to designate a separate
"manager" address that can buy Gobblers on your behalf. Intended for people who want to ensure that
Gobblers are protected in cold storage while still allowing a hot wallet to mint Gobblers on their
behalf, via a script like [automate-buyer](./script/automate-buyer.js).

## [Gnosis Safe "Buyer Module"](./src/GobblerBuyerModule.sol)

Deployed on mainnet at: [0xbBd44120c0FbC55583Df1e08dC11D386C02eDf7A](https://etherscan.io/address/0xbbd44120c0fbc55583df1e08dc11d386c02edf7a)

Similar to GOO Sitter except aimed at making the above setup more seamless for [Gnosis
Safe](https://gnosis-safe.io) users.

**How to use:**
1. Enable the module deployed at `(deployment pending)` in your safe
2. Configure the buying hot wallet via `setBuyer(address)`
3. The buying hot wallet can now buy on behalf of your safe by calling `buyFor(address safe, uint maxPrice)` on the module

The contract also has `removeAllGoo` and `removeAllGooAndTransferTo` methods to allow a safe to
easily remove and/or transfer out GOO without leaving behind dust.

**Note:** The designated can only spend accruing virtual GOO, if you want to set aside GOO you can
convert some virtual GOO to token GOO via the ArtGobbler's `removeGoo` method.


## Gobbler Thrones
> No one person can bear the might of a legendary gobbler, we shall bear it together!

`GobblerThrone` is a relatively simple pooling contract that can be deployed by
anybody. The deployed pools can be joined by anybody by depositing their revealed Gobblers.
The core goal is to make exposure to Legendary Gobblers more accessible to average holders.

If the legendary mint is successful the almighty, freshly minted legendary Gobbler
is placed upon the throne, out of all the participants' reach, accruing GOO, locked
in place until the throne is set to be dissolved. In exchange for their
sacrifice participants receive Gobbler Throne shares (or GOTTEM's).

Once the throne is set to dissolve, the Legendary Gobbler is auctioned off for
even more GOO. Once the auction is complete
and the throne is fully dissolved shares can be redeemed for a proportional
share of all the GOO that was accumulated in the throne contract.

### Specifics
#### Share Receival
Due to the decreasing price of legendary Gobblers the contract is first-come
first-served meaning if there's 60 Gobblers in the contract but the legendary
only costs 57, only the first 57 participants will be able to receive shares,
the last 3 will however be able to retrieve their unused Gobblers from the
throne contract (not including any accrued GOO). Shares are minted
proportionally to the emissions multiple of the deposited Gobbler(s).

#### Failure To Form
If the throne contract doesn't accrue sufficient Gobblers by a certain time it
can enter failure mode, allowing all participants to withdraw their Gobblers.
The time until the failure mode can be activated is set upon deployment.

#### Auction
The final auction is also set to begin at a certain time after throne creation
depending on the configured delay. The auction must go for at least 30 minutes
without bids before finalizing, this is to protect against last minute sniping
whereby people wait until the last moment to submit bids. Each bid must be at
least 5% higher than the previous.

#### GOO Withdrawal
To simplify the system and ensure the maximum amount of GOO is issued GOO can
only be withdrawn once the throne is dissolved. TODO: Have legendary Gobbler be
deposited in [Goo Stew](https://github.com/MrToph/goostew/) for even better GOO
production.
