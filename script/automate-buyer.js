require('dotenv').config()
const ethers = require('ethers')
const {
  FlashbotsBundleProvider,
  FlashbotsTransactionResolution
} = require('@flashbots/ethers-provider-bundle')
const { getMulticaller, createCallEncoder } = require('easy-multicall')

const gobblerCall = createCallEncoder(
  [
    'function gooBalance(address) view returns (uint256)',
    'function gobblerPrice() public view returns (uint256)',
    'function getVRGDAPrice(int256, uint256) public view returns (uint256)',
    'function gobblerRevealsData() view returns (uint64 randomSeed,uint64 nextRevealTimestamp,uint56 lastRevealid,uint56 toBeRevealed,bool waitingForSeed)'
  ],
  '0x60bb1e2aa1c9acafb4d34f71585d7e959f387769'
)

const sleep = (delay) =>
  new Promise((resolve) => setTimeout(() => resolve(), delay))

const wadToFloat = (wad) => parseFloat(ethers.utils.formatUnits(wad, 18))
const bnToFloat = (bn, unit) => parseFloat(ethers.utils.formatUnits(bn, unit))

const BAL_TO_PRICE_THRESHOLD = 1.25
const TIME_TO_REVEAL_THRESHOLD = 2.5 // hours
const GAS_PRICE_CAP = ethers.utils.parseUnits('50', 'gwei')

const divmod = (x, y) => [Math.floor(x / y), x % y]
const rounder2 = new Intl.NumberFormat('en', { maximumFractionDigits: 2 })
const formatTimeDelta = (td) => {
  const [totalMinutes, seconds] = divmod(td, 60)
  const [totalHours, minutes] = divmod(totalMinutes, 60)
  const [totalDays, hours] = divmod(totalHours, 24)
  const [weeks, days] = divmod(totalDays, 7)
  const components = [
    [weeks, 'w'],
    [days, 'd'],
    [hours, 'h'],
    [minutes, 'm'],
    [seconds, 's']
  ].filter(([units]) => units > 0)

  return components
    .map(([unit, char]) => `${rounder2.format(unit)}${char}`)
    .join(' ')
}

const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL)
const multicall = getMulticaller(
  '0xeefba1e63905ef1d7acba5a8513c70307c1ce441',
  provider
)
const managerSigner = new ethers.Wallet(process.env.MANAGER_PRIV_KEY)
console.log('managerSigner.address: ', managerSigner.address)
const gooSitter = new ethers.Contract(
  process.env.SITTER_ADDR,
  [
    'function buyGobbler(uint256) external',
    'function owner() view returns (address)'
  ],
  provider
)

async function sendBuy(flashbotsProvider) {
  const { baseFeePerGas } = await provider.getBlock('latest')
  const [bnPrice] = await multicall([gobblerCall('gobblerPrice')], {})
  const [estGas, nonce] = await Promise.all([
    gooSitter.estimateGas.buyGobbler(bnPrice, {
      from: managerSigner.address
    }),
    provider.getTransactionCount(managerSigner.address)
  ])
  try {
    const buyTx = await gooSitter.populateTransaction.buyGobbler(bnPrice, {
      type: 2,
      from: managerSigner.address,
      maxFeePerGas: baseFeePerGas.mul('143').div('100'),
      maxPriorityFeePerGas: ethers.utils.parseUnits('2', 'gwei'),
      gasLimit: Math.round(estGas * 1.2),
      nonce
    })
    buyTx.chainId = 1
    const res = await flashbotsProvider.sendPrivateTransaction({
      transaction: buyTx,
      signer: managerSigner
    })
    const { hash } = res.transaction
    console.log('hash:', hash)

    const waitRes = await res.wait()
    if (waitRes === FlashbotsTransactionResolution.TransactionIncluded) {
      console.log('Private transaction successfully included on-chain.')
    } else if (waitRes === FlashbotsTransactionResolution.TransactionDropped) {
      console.log(
        'Private transaction was not included in a block and has been removed from the system.'
      )
    }
  } catch (err) {
    console.log('err: ', err)
  }
}
async function main() {
  const flashbotsProvider = await FlashbotsBundleProvider.create(
    provider,
    managerSigner
  )

  while (true) {
    try {
      const [bnPrice, bnGooBal, { nextRevealTimestamp: bnNextReveal }] =
        await multicall(
          [
            gobblerCall('gobblerPrice'),
            gobblerCall('gooBalance', gooSitter.address),
            gobblerCall('gobblerRevealsData')
          ],
          {}
        )
      const { baseFeePerGas } = await provider.getBlock('latest')

      const [price, gooBal] = [bnPrice, bnGooBal].map(wadToFloat)
      const nextReveal = bnNextReveal.toNumber()

      const timeToReveal = nextReveal - Date.now() / 1000
      const Formatter = new Intl.NumberFormat('en', {
        style: 'percent',
        minimumFractionDigits: 3,
        maximumFractionDigits: 3
      })

      console.log(
        `Goo to price: ${Formatter.format(
          gooBal / price
        )} (target: ${Formatter.format(
          BAL_TO_PRICE_THRESHOLD
        )}, next reveal in ${formatTimeDelta(
          timeToReveal
        )}, gas price: ${rounder2.format(
          bnToFloat(baseFeePerGas, 'gwei')
        )} gwei)`
      )

      if (
        gooBal / price >= BAL_TO_PRICE_THRESHOLD &&
        0 <= timeToReveal &&
        timeToReveal <= TIME_TO_REVEAL_THRESHOLD * 60 * 60
        && baseFeePerGas.lte(GAS_PRICE_CAP)
      ) {
        await sendBuy(flashbotsProvider)
      } else {
        await sleep(4000)
      }
    } catch (err) {
      console.log(`${err} occured, sleeping...`)






      await sleep(20000)
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('err:', err)
    process.exit(1)
  })
