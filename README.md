# Sapphire tests

1. Install deps

```shell
npm i
```

2. Spin up Localnet

```shell
docker run -it -p8544-8548:8544-8548 -e OASIS_NODE_LOG_LEVEL=debug -e LOG__LEVEL=debug ghcr.io/oasisprotocol/sapphire-localnet
```

3. Run tests on Localnet

```shell
npm run test --network sapphire-localnet
```

4. Try on Testnet

```shell
PRIVATE_KEY=0x... npm run test --network sapphire-testnet
```
