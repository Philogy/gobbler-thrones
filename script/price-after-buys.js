const ethers = require('ethers')
const { BigNumber } = require('ethers/lib')
require('dotenv').config()

const getTimestamp = () => ethers.BigNumber.from(Math.floor(Date.now() / 1000))
const timeToDaysWad = (time) =>
  time.mul(BigNumber.from('1000000000000000000')).div(BigNumber.from('86400'))

const dec18ToFloat = (x) => parseFloat(ethers.utils.formatUnits(x))

async function main() {
  const formatter = Intl.NumberFormat('en', {
    notation: 'compact',
    maximumSignificantDigits: 3
  })
  const x = 120_398.09

  const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL)
  const gobbler = new ethers.Contract(
    '0x60bb1e2aa1c9acafb4d34f71585d7e959f387769',
    [
      'function gobblerPrice() view returns (uint256)',
      'function numMintedFromGoo() view returns (uint256)',
      'function mintStart() view returns (uint256)',
      'function getVRGDAPrice(int256 timeSinceStart, uint256 sold) public view returns (uint256)'
    ],
    provider
  )
  const args = process.argv.slice(2)
  const buys = parseInt(args[0])
  const [mintStart, numMinted, currentPrice] = await Promise.all([
    gobbler.mintStart(),
    gobbler.numMintedFromGoo(),
    gobbler.gobblerPrice()
  ])
  const priceAfterBuys = await gobbler.getVRGDAPrice(
    timeToDaysWad(getTimestamp().sub(mintStart)),
    BigNumber.from(buys).add(numMinted)
  )
  console.log(`current price: ${formatter.format(dec18ToFloat(currentPrice))}`)
  console.log(
    `price after buy (${buys}): ${formatter.format(
      dec18ToFloat(priceAfterBuys)
    )}`
  )
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('err:', err)
    process.exit(1)
  })
