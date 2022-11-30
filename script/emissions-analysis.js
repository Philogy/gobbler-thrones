require('dotenv').config()
const ethers = require('ethers')
const { getMulticaller, createCallEncoder } = require('easy-multicall')
const _ = require('lodash')

const gobblerCall = createCallEncoder(
  [
    'function ownerOf(uint256) view returns (address)',
    'function getUserEmissionMultiple(address) view returns (uint32)',
    'function gooBalance(address) view returns (uint256)',
    'function gobblerPrice() public view returns (uint256)',
    'function getVRGDAPrice(int256, uint256) public view returns (uint256)',
    'function currentNonLegendaryId() public view returns (uint128)'
  ],
  '0x60bb1e2aa1c9acafb4d34f71585d7e959f387769'
)

async function main() {
  const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL)
  const multicall = getMulticaller(
    '0xeefba1e63905ef1d7acba5a8513c70307c1ce441',
    provider
  )
  const currentBlock = await provider.getBlockNumber()
  const [totalMinted] = await multicall(
    [gobblerCall('currentNonLegendaryId')],
    { blockTag: currentBlock }
  )
  const tokenIds = _.range(1, totalMinted.toNumber() + 1)
  const sortedOwners = await multicall(
    tokenIds.map((tokenId) => gobblerCall('ownerOf', tokenId)),
    { blockTag: currentBlock }
  )
  const ownerOf = Object.fromEntries(_.zip(tokenIds, sortedOwners))
  const ownedTokens = {}
  for (const [tokenId, owner] of Object.entries(ownerOf)) {
    const ownedTokenSet = ownedTokens[owner] ?? new Set()
    ownedTokenSet.add(tokenId)
    ownedTokens[owner] = ownedTokenSet
  }
  const owners = Array.from(Object.keys(ownedTokens))
  const emissionMultiples = Object.fromEntries(
    _.zip(
      owners,
      await multicall(
        owners.map((owner) => gobblerCall('getUserEmissionMultiple', owner)),
        { blockTag: currentBlock }
      )
    )
  )
  const totalEmissions = _.sum(Object.values(emissionMultiples))
  const users = owners.map((owner) => ({
    addr: owner,
    balanceOf: ownedTokens[owner].size,
    emissionMultiple: emissionMultiples[owner]
  }))
  const sortedUsers = _.reverse(_.sortBy(users, ['emissionMultiple']))
  const Formatter = new Intl.NumberFormat('en', {
    style: 'percent',
    minimumFractionDigits: 3,
    maximumFractionDigits: 3
  })
  console.log('totalEmissions: ', totalEmissions)
  sortedUsers.forEach(({ addr, balanceOf, emissionMultiple }, i) => {
    console.log(
      `#${i + 1} ${addr} ${Formatter.format(
        emissionMultiple / totalEmissions
      )} (${balanceOf} - ${emissionMultiple})`
    )
  })
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('err:', err)
    process.exit(1)
  })
