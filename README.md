# Tura11 Staking Platform

A production-grade ERC20 staking protocol built with Foundry. Users stake any ERC20 token and earn **T11 (Tura11)** — a proprietary reward token — distributed continuously over configurable reward periods.

Implements the **Synthetix `rewardPerToken` accumulator pattern** for gas-efficient, proportional reward distribution across an arbitrary number of stakers.

---

## Architecture

```
StakingFactory
└── createPool(stakedToken) → StakingPool
        ├── stake()
        ├── withdraw()
        ├── claimReward()
        ├── exit()
        ├── emergencyWithdraw()
        └── notifyRewardAmount()  [onlyOwner]

Tura11ERC20 (T11)
└── Reward token injected into every pool
```

### Contracts

| Contract | Description |
|----------|-------------|
| `StakingPool.sol` | Core staking logic. Holds staked tokens, tracks rewards per staker, distributes T11. |
| `StakingFactory.sol` | Deploys and registers `StakingPool` instances. One pool per staked token. |
| `Tura11ERC20.sol` | Proprietary ERC20 reward token (T11). Pre-funded by owner before each reward period. |

---

## How It Works

### Reward Math

Rewards are distributed using a global accumulator `rewardPerTokenStored` that increases monotonically over time:

```
rewardPerToken += (timeDelta * rewardRate * 1e18) / totalSupply
```

Each user's pending rewards are derived from the delta between the current accumulator and their personal checkpoint:

```
earned(user) = balance * (rewardPerToken_NOW - userRewardPerTokenPaid) / 1e18 + rewards[user]
```

This design ensures O(1) reward calculation regardless of the number of stakers, and guarantees that:
- Late stakers never earn rewards retroactively
- Rewards stop accruing after `periodFinish`
- Partial withdrawals preserve all earned-but-unclaimed rewards

### Reward Period

The owner funds a reward period by calling `notifyRewardAmount(reward, duration)`:

```
rewardRate = reward / duration   // tokens per second
periodFinish = block.timestamp + duration
```

If a new period is started before the previous one ends, the remaining undistributed rewards (`leftover`) are rolled into the new rate:

```
rewardRate = (newReward + leftover) / newDuration
```

This prevents any T11 from being stranded in the contract across period transitions.

> **Note**: Integer division truncation means up to `(duration - 1)` wei of T11 may remain permanently undistributed per period. At standard token decimals (1e18) this is economically negligible.

---

## Getting Started

### Prerequisites

- [Foundry](https://getfoundry.sh/)
- Node.js (for any tooling scripts)

### Installation

```bash
git clone https://github.com/tura11/staking-platform
cd staking-platform
forge install
```

### Build

```bash
forge build
```

### Test

```bash
# All tests
forge test

# With verbosity
forge test -vvvv

# Specific test file
forge test --mc StakingPoolTest
forge test --mc StakingPoolInvariant
```

### Coverage

```bash
forge coverage
```

---

## Deployment

### Deploy via Factory

```solidity
// 1. Deploy T11 reward token
Tura11ERC20 rewardToken = new Tura11ERC20();

// 2. Deploy factory
StakingFactory factory = new StakingFactory(address(rewardToken));

// 3. Create a pool for any ERC20
address pool = factory.createPool(address(myStakeToken));

// 4. Fund the pool with rewards and start a period
rewardToken.approve(pool, 1_000_000e18);
StakingPool(pool).notifyRewardAmount(1_000_000e18, 30 days);
```

### Deploy on Sepolia

```bash
# Using Foundry keystore (recommended)
cast wallet import deployer --interactive

forge script script/Deploy.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --account deployer \
  --broadcast
```

---

## User Guide

### Staking

```solidity
// Approve and stake
IERC20(stakeToken).approve(address(pool), amount);
pool.stake(amount);
```

### Checking Rewards

```solidity
// Live earned amount (includes unsnapshotted rewards)
uint256 pending = pool.earned(msg.sender);
```

### Claiming

```solidity
// Claim rewards only
pool.claimReward();

// Withdraw all stake + claim rewards atomically
pool.exit();
```

### Emergency Withdraw

```solidity
// Withdraw stake immediately, forfeit ALL pending rewards
// Use only if normal withdraw is broken
pool.emergencyWithdraw();
```

---

## Owner Functions

| Function | Description |
|----------|-------------|
| `notifyRewardAmount(reward, duration)` | Fund a new reward period. Requires prior `approve`. Max duration: 30 days. |
| `emergencyWithdrawAll()` | Drain entire pool (stake + reward tokens) to owner. Use only during active exploit. |

---

## Security

### Reentrancy
`stake()`, `withdraw()`, and `claimReward()` are individually protected by OpenZeppelin `ReentrancyGuard`. `exit()` delegates to these functions and inherits their protection without requiring its own guard.

### Access Control
All owner-gated functions use OpenZeppelin `Ownable`. Pool ownership is transferred from the factory to the factory owner immediately on deployment — the factory itself retains no administrative control over deployed pools.

### Known Limitations
- `emergencyWithdraw()` skips the `updateReward` modifier by design. Accrued-but-unsnapshotted rewards (rewards earned since the last user interaction) are permanently lost on emergency exit. This is intentional — the function exists for scenarios where normal accounting is broken.
- Integer division truncation in `rewardRate` calculation may leave a small amount of T11 (< `duration` wei) permanently in the contract after each period.

---

## Testing

The test suite covers three layers:

### Unit Tests (`test/unit/`)
Deterministic scenario tests covering all core functions, revert conditions, events, and edge cases including late stakers, proportional rewards, and multi-period transitions.

### Fuzz Tests (`test/fuzz/`)
Property-based tests with randomised inputs verifying:
- `rewardRate * duration <= reward` (no over-distribution)
- Stake/withdraw balance integrity across arbitrary amounts
- `earned()` monotonicity over time

### Invariant Tests (`test/invariants/`)
Stateful tests using a `Handler` contract that executes random sequences of `stake`, `withdraw`, `claimReward`, `notifyRewardAmount`, and time warps. Verified invariants:

| Invariant | Description |
|-----------|-------------|
| `totalSupply == Σ balances` | Bookkeeping integrity |
| `balanceOf(pool) >= Σ earned()` | Reward solvency |
| `totalRewardDeposited >= Σ earned()` | No over-earning |
| `stakeToken.balanceOf(pool) == Σ getUserBalance()` | Stake solvency |

---

## Project Structure

```
src/
├── StakingPool.sol
├── StakingFactory.sol
└── Tura11ERC20.sol

test/
├── unit/
│   ├── StakingPool.t.sol
│   └── StakingFactory.t.sol
├── fuzz/
│   └── StakingPoolFuzz.t.sol
└── invariants/
    ├── HandlerPool.t.sol
    └── StakingPoolInvariant.t.sol

script/
└── Deploy.s.sol
```

---

## License

MIT
