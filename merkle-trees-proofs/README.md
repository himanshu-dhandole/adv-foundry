# Merkle Airdrop (Cyfrin Updraft Course)

This project contains an end-to-end implementation of a token airdrop using Merkle Trees and EIP-712 Signatures, built as part of the Cyfrin Updraft Advanced Foundry course.

## The Airdrop Flow

Below is the step-by-step process of how we deploy, generate our signatures, and claim the airdrop!

### 1. Deployed Contract Addresses
Once the contracts are deployed to Sepolia, take note of the addresses:
```text
Token Address: 0xe76627b98f29CC7E5e06711228cF21fc1f76FB58  
Merkle Airdrop Address: 0x08b63EaaC4616a3e856e161055ABa2a36f684280
```

### 2. Generate the EIP-712 Message Hash
Before a user can claim their airdrop gaslessly, they must sign an intent to claim. We first query the smart contract to formulate the correct EIP-712 digest (message hash) specific to our contract address, chain ID, claiming address, and amount:

```bash
cast call 0x08b63EaaC4616a3e856e161055ABa2a36f684280 \
  "getMessageHash(address _address, uint256 _amount)" \
  0x2a3D206626337FcAC4C5Cfc0f9fBe18F9D900f47 \
  2500000000000000000000 \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/TuaU6pL-QOrGnH7n7so2h
```
**Output Hash:**
```text
0xe6a00feb16446cd25fe0057e91eb82ba8b210c8433d4e8b39c9af1fb3c6ff941
```

### 3. Sign the Message Hash
Now that we have the 32-byte message hash, the eligible user must sign it using their private key.

```bash
cast wallet sign --no-hash \
  0xe6a00feb16446cd25fe0057e91eb82ba8b210c8433d4e8b39c9af1fb3c6ff941 \
  --private-key 96305d6713ad0da88eaef9fd8591f9cab8e310c974a713695701c0bafa2531f5
```
**Signed Message Result:**
```text
0x1609c8de9db0f5045a4e333c0e6369edf9e5ac80e9ce6db03e10fd32bd02018a5dab5dcf6aad040928bb33b460b99820608594876d9c5db8d2b6780c1f9ebc861b
```

### 4. Claiming the Airdrop
Once the message is successfully signed, the signature (`v`, `r`, `s`) can be extracted from the output above, and passed to the Airdrop contract alongside the Merkle proofs. 

A relayer or sponsor can execute the `claim` function dynamically with this signature, allowing the user to receive their airdropped tokens without paying gas fees!

---

## Technical Details

- **AuraToken.sol:** The custom ERC20 being distributed via the airdrop.
- **MerkleAirdrop.sol:** Validates the Merkle proofs against the `merkleRoot`, and verifies the ECDSA EIP-712 signature over the transaction details.
- **Scripts:** `GenerateInput.s.sol` and `MakeMerkle.s.sol` construct the Merkle roots locally before deployment.