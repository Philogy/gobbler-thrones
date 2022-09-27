# Gobbler Thrones
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

## Specifics
### Share Receival
Due to the decreasing price of legendary Gobblers the contract is first-come
first-served meaning if there's 60 Gobblers in the contract but the legendary
only costs 57, only the first 57 participants will be able to receive shares,
the last 3 will however be able to retrieve their unused Gobblers from the
throne contract (not including any accrued GOO). Shares are minted
proportionally to the emissions multiple of the deposited Gobbler(s).

### Failure To Form
If the throne contract doesn't accrue sufficient Gobblers by a certain time it
can enter failure mode, allowing all participants to withdraw their Gobblers.
The time until the failure mode can be activated is set upon deployment.

### Auction
The final auction is also set to begin at a certain time after throne creation
depending on the configured delay. The auction must go for at least 30 minutes
without bids before finalizing, this is to protect against last minute sniping
whereby people wait until the last moment to submit bids. Each bid must be at
least 5% higher than the previous.

### GOO Withdrawal
To simplify the system and ensure the maximum amount of GOO is issued GOO can
only be withdrawn once the throne is dissolved. TODO: Have legendary Gobbler be
deposited in [Goo Stew](https://github.com/MrToph/goostew/) for even better GOO
production.

## Testing
TODO: Need to actually test the contract :P
