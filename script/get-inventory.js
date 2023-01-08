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
    'function currentNonLegendaryId() public view returns (uint128)',
    'function getGobblerEmissionMultiple(uint256) returns (uint256)',
    'function getGobblerData(uint256) returns (address owner, uint64 idx, uint32 emissionMultiple)'
  ],
  '0x60bb1e2aa1c9acafb4d34f71585d7e959f387769'
)

async function main() {
  const [, , inpAddr] = process.argv
  const targetAddr = ethers.utils.getAddress(inpAddr)
  const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL)
  const multicall = getMulticaller('0xeefba1e63905ef1d7acba5a8513c70307c1ce441', provider)
  const [totalMinted] = await multicall([gobblerCall('currentNonLegendaryId')], {})
  const tokenIds = _.range(1, totalMinted.toNumber() + 1)

  console.log('getting all owners')
  const gobblerData = await multicall(
    tokenIds.map((tokenId) => gobblerCall('getGobblerData', tokenId)),
    {}
  )
  const sortedOwners = _.map(gobblerData, 'owner')

  console.log('filtering for target owner')
  const targetGobblers = _.zip(tokenIds, sortedOwners)
    .filter(([, owner]) => owner === targetAddr)
    .map(([gobbler]) => gobbler)

  console.log('getting multiples')
  const multiples = await multicall(
    targetGobblers.map((gobbler) => gobblerCall('getGobblerEmissionMultiple', gobbler)),
    {}
  )
  for (const [gobbler, multiple] of _.zip(targetGobblers, multiples)) {
    console.log(`${gobbler}: x${multiple}`)
  }
  if (multiples.length >= 1) {
    const totalMultiple = multiples.reduce((total, x) => total.add(x))
    console.log(`Total Multiple (${multiples.length}): ${totalMultiple}`)
  } else {
    console.log('No gobblers')
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    // console.error('err:', err)
    const fs = require('fs')
    fs.writeFileSync('./error.json', JSON.stringify(err, null, 2))
    console.log('saved error')
    process.exit(1)
  })
