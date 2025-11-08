# Testing Reveals with Time Manipulation

**NO CONTRACT MODIFICATIONS NEEDED** - Use Foundry's built-in time manipulation to test the REAL production contract.

## Three Ways to Test

### Option 1: Foundry Tests (Easiest)

Run automated tests that warp through time:

```bash
# Run all reveal transition tests
forge test --match-contract RevealTransition -vvv

# Run specific test
forge test --match-test testRevealTransitionSingleToken -vvv

# Test 100-token fast-forward
forge test --match-test testFastForward100Tokens -vvv
```

**What it does:**
- Deploys REAL EveryTwoMillionBlocks contract
- Mints tokens
- Uses `vm.warp()` to jump forward in time
- Tests countdown → reveal transition
- Saves metadata to `OUTPUTS/test-*.txt`

**Files created:** `test/RevealTransition.t.sol`

---

### Option 2: Local Anvil Node (Most Realistic)

Run a local Ethereum blockchain and manually control time:

#### Step 1: Start Anvil
```bash
anvil
```

Anvil will start on `http://localhost:8545` with instant mining.

#### Step 2: Deploy to Local Chain
```bash
forge script script/testnet/TestRevealWithTimeWarp.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast

source deployed-timewarp.env
```

#### Step 3: Check Pre-Reveal State
```bash
# Token 1 metadata (should show countdown)
cast call $NFT "tokenURI(uint256)" 1 --rpc-url http://localhost:8545
```

#### Step 4: Fast-Forward Time

**To Jan 1, 2026 (Token 1 reveals):**
```bash
# Calculate seconds from now to Jan 1, 2026
# Jan 1, 2026 = 1735689600

# Fast-forward (31,536,000 seconds = 1 year approximately)
cast rpc evm_increaseTime 31536000 --rpc-url http://localhost:8545

# Mine a block to apply the time change
cast rpc anvil_mine 1 --rpc-url http://localhost:8545
```

#### Step 5: Reveal Token
```bash
# Prepare reveal
cast send $NFT "prepareReveal(uint256)" 1 \
  --rpc-url http://localhost:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Finalize reveal  
cast send $NFT "finalizeReveal(uint256)" 1 \
  --rpc-url http://localhost:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

#### Step 6: Check Post-Reveal State
```bash
# Token 1 metadata (should show staff notation + audio)
cast call $NFT "tokenURI(uint256)" 1 --rpc-url http://localhost:8545
```

#### Step 7: Reveal More Tokens
```bash
# Jump another year (to 2027 for token 2)
cast rpc evm_increaseTime 31536000 --rpc-url http://localhost:8545
cast rpc anvil_mine 1 --rpc-url http://localhost:8545

# Reveal token 2
cast send $NFT "prepareReveal(uint256)" 2 --rpc-url http://localhost:8545 --private-key 0xac...
cast send $NFT "finalizeReveal(uint256)" 2 --rpc-url http://localhost:8545 --private-key 0xac...
```

**Repeat for as many tokens as you want to test!**

---

### Option 3: Testnet with Modified Timing (If Really Needed)

If you absolutely need to test on Sepolia with fast reveals, we can:
1. Create a `FastRevealReal.sol` that inherits from EveryTwoMillionBlocks
2. Make `getCurrentRank()` and `_jan1Timestamp()` virtual in base contract
3. Override only those two functions

But **Options 1 & 2 are better** because they don't modify production code.

---

## Recommended Testing Flow

### Phase 1: Local Tests (5 minutes)
```bash
forge test --match-contract RevealTransition -vvv
```
- Fastest
- Tests all logic
- Saves metadata files for inspection

### Phase 2: Anvil Testing (30 minutes)
```bash
# Terminal 1: Start Anvil
anvil

# Terminal 2: Deploy and test
forge script script/testnet/TestRevealWithTimeWarp.s.sol --rpc-url http://localhost:8545 --broadcast
# ... then use cast commands above
```
- More realistic (actual blockchain)
- Can manually inspect each step
- Test UI/UX flow

### Phase 3: Sepolia Testnet (if needed)
- Deploy actual contract to Sepolia
- Wait for real time to pass (or use FastRevealReal variant)
- Test marketplace integration

---

## Anvil Time Manipulation Commands

### Set Specific Timestamp
```bash
# Jump to Jan 1, 2026 exactly
cast rpc evm_setNextBlockTimestamp 1735689600 --rpc-url http://localhost:8545
cast rpc anvil_mine 1 --rpc-url http://localhost:8545
```

### Increase Time by Duration
```bash
# Add 1 hour
cast rpc evm_increaseTime 3600 --rpc-url http://localhost:8545

# Add 1 day
cast rpc evm_increaseTime 86400 --rpc-url http://localhost:8545

# Add 1 year
cast rpc evm_increaseTime 31536000 --rpc-url http://localhost:8545

# Then mine a block
cast rpc anvil_mine 1 --rpc-url http://localhost:8545
```

### Mine Multiple Blocks at Once
```bash
# Mine 100 blocks instantly
cast rpc anvil_mine 100 --rpc-url http://localhost:8545
```

### Reset to Current Time
```bash
# Reset (restart anvil)
# Ctrl+C and restart
anvil
```

---

## Extracting & Viewing Metadata

### From Test Output
```bash
# Tests save to OUTPUTS/
base64 -d OUTPUTS/test-countdown.txt > /tmp/countdown.json
base64 -d OUTPUTS/test-revealed.txt > /tmp/revealed.json

jq '.' /tmp/countdown.json
jq '.' /tmp/revealed.json

# Extract SVG
jq -r '.image' /tmp/countdown.json | sed 's/data:image\/svg+xml;base64,//' | base64 -d > /tmp/countdown.svg
jq -r '.image' /tmp/revealed.json | sed 's/data:image\/svg+xml;base64,//' | base64 -d > /tmp/revealed.svg

open /tmp/countdown.svg
open /tmp/revealed.svg
```

### From Anvil/Cast Output
```bash
# Get tokenURI output
cast call $NFT "tokenURI(uint256)" 1 --rpc-url http://localhost:8545 > /tmp/raw.txt

# Decode hex to string, extract base64, decode
xxd -r -p /tmp/raw.txt | sed 's/^.*data:application\/json;base64,//' | base64 -d | jq '.' > /tmp/metadata.json
```

---

## Why This is Better

| Approach | Pros | Cons |
|----------|------|------|
| **Foundry Tests** | ✅ Instant<br>✅ Automated<br>✅ No setup | ❌ Not interactive |
| **Anvil Local** | ✅ Realistic<br>✅ Manual control<br>✅ Test UX | ❌ Requires terminal multitasking |
| **Modified Contract** | ✅ Works on testnet | ❌ Changes production code<br>❌ Need to maintain variant |

**Recommendation:** Use Foundry tests for rapid iteration, then Anvil for final validation.

---

## Testing Checklist

Using Foundry tests or Anvil, verify:

### Pre-Reveal State
- [ ] Countdown shows 12-digit odometer
- [ ] Countdown SVG is valid XML
- [ ] Metadata has correct structure
- [ ] Time calculations are accurate

### Reveal Transition
- [ ] prepareReveal() works after time threshold
- [ ] finalizeReveal() generates music
- [ ] Metadata changes from countdown to staff notation
- [ ] No errors in two-step process

### Post-Reveal State
- [ ] Staff notation renders correctly
- [ ] Clefs and notes positioned properly
- [ ] Audio HTML player included
- [ ] All metadata attributes present
- [ ] Note names are correct (e.g., "G4+Bb2")

### Multiple Tokens
- [ ] Sequential reveals work (year after year)
- [ ] Each token gets unique music (different seeds)
- [ ] Ranking system works (using simple tokenID order)

---

## Example Test Run

```bash
$ forge test --match-test testRevealTransitionSingleToken -vvv

=== TEST: Single Token Reveal Transition ===
Token 1 rank: 0

--- PRE-REVEAL STATE ---
Metadata length: 15234

Warping from 1 to 1735689600
Current time after warp: 1735689600

--- PREPARING REVEAL ---
--- FINALIZING REVEAL ---

--- POST-REVEAL STATE ---
Metadata length: 18567

SUCCESS: Token transitioned from countdown to revealed state!

Test result: ok. 1 passed; 0 failed
```

Success! No contract modifications needed.
