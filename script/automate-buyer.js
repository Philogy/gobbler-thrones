require('dotenv').config()
const ethers = require('ethers')

const Gobblers = new ethers.Contract(
  '0x60bb1e2aa1c9acafb4d34f71585d7e959f387769',
  [
    'function gooBalance(address) view returns (uint256)',
    'function gobblerPrice() public view returns (uint256)',
    'function getVRGDAPrice(int256, uint256) public view returns (uint256)'
  ]
)

const gooSitter = new ethers.Contract(process.env.SITTER_ADDR, [
  'function buyGobbler(uint256) external'
])

const sleep = (delay) =>
  new Promise((resolve) => setTimeout(() => resolve(), delay))

async function main() {
  const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL)
  const gobblers = Gobblers.connect(provider)
  const managerSigner = new ethers.Wallet(process.env.MANAGER_PRIV_KEY)
  // repeat forever:
  // 1. Get Gobbler Price
  // 2. Get virtual GOO balance
  // 3. Submit buy
  while (true) {
    const price = await gobblers.gobblerPrice()
    const gooBal = await gobblers.gooBalance(gooSitter.address)
    console.log(
      `GOO: ${ethers.utils.formatUnits(
        gooBal
      )} (price = ${ethers.utils.formatUnits(price)}, ${gooBal.gte(price)})`
    )
    await sleep(4000)
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('err:', err)
    process.exit(1)
  })
