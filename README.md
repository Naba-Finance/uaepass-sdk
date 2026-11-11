# @naba-finance/uaepass

Solidity interfaces and deployment addresses for integrating **UAE Pass on-chain identity**.

Use this package to gate your contracts on UAE Pass *provenance* — for example, a token that only addresses created by an official UAE Pass account can hold or receive.

> This is the public **integration** package. It ships interfaces + addresses only; the implementation contracts, validator, and ZK circuit live in a separate repository.

## What it provides

- [`ICredential`](contracts/ICredential.sol) — interface to the UAE Pass `Credential` contract. The key method is:

  ```solidity
  function wasCreatedByUAEPass(address account) external view returns (bool);
  ```

  It returns `true` iff `account` was deployed through one of the currently trusted UAE Pass account factories **and** has executed at least one UserOperation through the UAE Pass validator (`EntryPoint.getNonce(account, 0) > 0`).

- [`deployments/addresses.json`](deployments/addresses.json) — canonical contract addresses.

### What `wasCreatedByUAEPass` means (and doesn't)

It is a **provenance** check: "was this address created by an official UAE Pass factory and authorised at least once through UAE Pass." It does **not** assert real-time control of the account, KYC/identity status, or that any particular validator is still installed. Gate on it when "is this one of our accounts" is the question you're answering.

Deployment alone is not enough: `AccountFactory.createAccount` is permissionless and accepts any identity commitment, so anyone can deploy an account that no one can operate. The nonce check excludes such inert accounts. Consequences:

- **An account becomes eligible during its first UserOperation**, not at deployment. A freshly deployed account that has not yet sent a UserOperation cannot receive a token gated on this predicate.
- **Eligibility is monotonic** while the factory stays trusted: the nonce never decreases.
- **False negatives only.** An account that only ever uses a non-zero nonce key stays ineligible. The Naba wallet always uses nonce key 0.
- **Execution only.** Do not call it from `validateUserOp` or paymaster validation: it reads EntryPoint and factory storage, which ERC-7562 forbids during validation.

## Deployed addresses

All contracts use a **same-address deployment**: the address is identical on every supported chain (CREATE2 via Arachnid's deterministic deployment proxy).

| Contract        | Address                                      |
| --------------- | -------------------------------------------- |
| `Credential`     | `0x8bA9eB1FF63DEd9145d341f316758e6Ca132Cb0e` |
| `FactoryAdapter` | `0x8B8dDa76Ba45dD79a6011B6fbaCFaEB209BA7290` |
| `AccountFactory` | `0x3B56036FeE71527879E8a423DDcF327e08aD00A8` |
| `Registry`       | `0x9B66841644a49187b34660fEb05d057f7f4a3C4E` |
| `Validator`      | `0x07656Fb863E3181664014124604f6fE5A2836206` |
| `Verifier`       | `0xDe29EFC7d5E21308a8AE2f95fE0946D96581427f` |
| `KernelFactory`  | `0xaac5D4240AF87249B3f71BC8E4A2cae074A3E419` |

`FactoryAdapter` is the only factory in `Credential`'s trusted list. It wraps `AccountFactory` and adds the nonce check. `AccountFactory` is where accounts are deployed, but it is **not** a trusted factory itself: `isTrustedFactory(AccountFactory)` is `false`, and its own `deployedByThisFactory` also returns `true` for inert accounts. Always gate through `Credential`.

| Chain         | Chain ID | Network |
| ------------- | -------- | ------- |
| Polygon PoS   | 137      | mainnet |
| Polygon Amoy  | 80002    | testnet |
| ADI           | 36900    | mainnet |
| ADI           | 99999    | testnet |

For most integrations you only need **`Credential`**.

## Install

```bash
npm install @naba-finance/uaepass
```

### Hardhat

Import directly from `node_modules`:

```solidity
import {ICredential} from "@naba-finance/uaepass/contracts/ICredential.sol";
```

### Foundry

Foundry resolves `node_modules`. Add a remapping (see [`remappings.txt`](remappings.txt)):

```
@naba-finance/uaepass/=node_modules/@naba-finance/uaepass/
```

then import the same way:

```solidity
import {ICredential} from "@naba-finance/uaepass/contracts/ICredential.sol";
```

## Usage — gating a token

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ICredential} from "@naba-finance/uaepass/contracts/ICredential.sol";

/// @notice ERC-20 holdable only by UAE Pass accounts.
contract GatedToken is ERC20 {
    ICredential public immutable credential;

    error NotUAEPassAccount(address account);

    constructor(ICredential _credential) ERC20("Gated", "GATE") {
        credential = _credential; // 0x8bA9eB1FF63DEd9145d341f316758e6Ca132Cb0e
    }

    // OZ v5 transfer hook — runs on mint, transfer, and burn.
    function _update(address from, address to, uint256 value) internal override {
        // Allow burns (to == address(0)); gate every recipient otherwise.
        // Note: a new account becomes eligible during its first UserOperation.
        if (to != address(0) && !credential.wasCreatedByUAEPass(to)) {
            revert NotUAEPassAccount(to);
        }
        super._update(from, to, value);
    }
}
```

Reading the predicate off-chain (viem):

```ts
import { createPublicClient, http } from "viem";
import { polygon } from "viem/chains";

const client = createPublicClient({ chain: polygon, transport: http() });

const isUAEPass = await client.readContract({
  address: "0x8bA9eB1FF63DEd9145d341f316758e6Ca132Cb0e",
  abi: [{
    type: "function",
    name: "wasCreatedByUAEPass",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ type: "bool" }],
  }],
  functionName: "wasCreatedByUAEPass",
  args: [userAddress],
});
```

## License

MIT — see [LICENSE](LICENSE).
