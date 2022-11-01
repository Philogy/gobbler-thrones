const rlp = require('rlp')
const keccak = require('keccak')

async function main() {
  const getDetAddr = (addr, nonce) => {
    const rlpEncoded = rlp.encode([addr, nonce])
    console.log('rlpEncoded: ', Buffer.from(rlpEncoded).toString('hex'))
    const resHash = keccak('keccak256')
      .update(Buffer.from(rlpEncoded))
      .digest('hex')

    const emptyhash = keccak('keccak256').digest('hex')
    console.log('emptyhash: ', emptyhash)

    const contractAddr = `0x${resHash.substring(24)}`
    return contractAddr
  }

  const addr = '0x77f4780189d87f3ec7af925ada7d0d7828867adc'
  console.log('getDetAddr(addr, 0): ', getDetAddr(addr, 0))
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('err:', err)
    process.exit(1)
  })
