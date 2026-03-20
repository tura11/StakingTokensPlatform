'use client';

import { ConnectButton } from '@rainbow-me/rainbowkit';
import { useState } from 'react';
import { useAccount } from 'wagmi';
import { formatEther } from 'viem';
import { useStakingPool } from '@/src/hooks/useStakingPool';
import { useStakingActions } from '@/src/hooks/useStakingActions';
import { useClaimedTotal } from '@/src/hooks/useClaimedTotal';

export default function Home() {
  const { isConnected } = useAccount();
  const { totalSupply, userBalance, earned, rewardRate, periodFinish } = useStakingPool();
  const { approve, stake, withdraw, claimReward, exit, isPending, isConfirming } = useStakingActions();
  const { totalClaimedFormatted } = useClaimedTotal();

  const [stakeAmount, setStakeAmount] = useState('');
  const [withdrawAmount, setWithdrawAmount] = useState('');
  const [activeTab, setActiveTab] = useState<'stake' | 'withdraw'>('stake');

  const fmt = (val: bigint | undefined) =>
    val !== undefined ? parseFloat(formatEther(val)).toFixed(4) : '—';

  const timeLeft = periodFinish
    ? Math.max(0, Number(periodFinish) - Math.floor(Date.now() / 1000))
    : 0;

  const daysLeft = Math.floor(timeLeft / 86400);
  const hoursLeft = Math.floor((timeLeft % 86400) / 3600);

  const loading = isPending || isConfirming;

  return (
    <main style={{ position: 'relative', zIndex: 1, minHeight: '100vh', padding: '32px 24px', maxWidth: '1200px', margin: '0 auto' }}>
      <div className="scanline" />

      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '48px' }}>
        <div>
          <div style={{ fontFamily: 'var(--font-orbitron)', fontSize: '10px', letterSpacing: '0.3em', color: 'var(--text-dim)', marginBottom: '6px' }}>
            PROTOCOL // DEFI STAKING
          </div>
          <h1 style={{ fontFamily: 'var(--font-orbitron)', fontSize: '28px', fontWeight: 900, color: 'var(--accent)', textShadow: '0 0 30px rgba(0,212,255,0.5)', letterSpacing: '0.1em' }}>
            TURA11 <span style={{ color: 'var(--text-dim)' }}>/</span> STAKING
          </h1>
        </div>
        <ConnectButton />
      </div>

      {/* Stats Row */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: '16px', marginBottom: '24px' }}>
        {[
          { label: 'Total Staked', value: fmt(totalSupply), unit: 'TKN' },
          { label: 'Reward Rate', value: rewardRate ? fmt(rewardRate) : '—', unit: 'T11/s' },
          { label: 'Your Stake', value: fmt(userBalance), unit: 'TKN' },
          { label: 'Total Claimed', value: totalClaimedFormatted, unit: 'T11' },
          { label: 'Period Ends', value: timeLeft > 0 ? `${daysLeft}d ${hoursLeft}h` : 'ENDED', unit: '' },
        ].map((stat) => (
          <div key={stat.label} className="card" style={{ padding: '20px' }}>
            <span className="label">{stat.label}</span>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: '8px', marginTop: '8px' }}>
              <span className="value" style={{ fontSize: '18px' }}>{stat.value}</span>
              <span style={{ color: 'var(--text-dim)', fontSize: '11px', fontFamily: 'var(--font-orbitron)' }}>{stat.unit}</span>
            </div>
          </div>
        ))}
      </div>

      {/* Main Grid */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 360px', gap: '16px' }}>

        {/* Left — Stake/Withdraw */}
        <div className="card" style={{ padding: '28px' }}>
          {/* Tabs */}
          <div style={{ display: 'flex', gap: '0', marginBottom: '28px', borderBottom: '1px solid var(--border)' }}>
            {(['stake', 'withdraw'] as const).map((tab) => (
              <button
                key={tab}
                onClick={() => setActiveTab(tab)}
                style={{
                  fontFamily: 'var(--font-orbitron)',
                  fontSize: '10px',
                  fontWeight: 700,
                  letterSpacing: '0.2em',
                  textTransform: 'uppercase',
                  padding: '12px 24px',
                  background: 'transparent',
                  border: 'none',
                  borderBottom: activeTab === tab ? '2px solid var(--accent)' : '2px solid transparent',
                  color: activeTab === tab ? 'var(--accent)' : 'var(--text-dim)',
                  cursor: 'pointer',
                  transition: 'all 0.2s',
                  marginBottom: '-1px',
                }}
              >
                {tab}
              </button>
            ))}
          </div>

          {activeTab === 'stake' ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div>
                <span className="label">Amount to Stake</span>
                <input
                  className="input"
                  type="number"
                  placeholder="0.0000"
                  value={stakeAmount}
                  onChange={(e) => setStakeAmount(e.target.value)}
                />
              </div>
              <div style={{ display: 'flex', gap: '12px' }}>
                <button
                  className="btn"
                  onClick={() => approve(stakeAmount)}
                  disabled={!isConnected || loading || !stakeAmount}
                  style={{ flex: 1, opacity: !isConnected || !stakeAmount ? 0.4 : 1 }}
                >
                  {loading ? 'PENDING...' : 'APPROVE'}
                </button>
                <button
                  className="btn btn-green"
                  onClick={() => stake(stakeAmount)}
                  disabled={!isConnected || loading || !stakeAmount}
                  style={{ flex: 1, opacity: !isConnected || !stakeAmount ? 0.4 : 1 }}
                >
                  {loading ? 'PENDING...' : 'STAKE'}
                </button>
              </div>
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div>
                <span className="label">Amount to Withdraw</span>
                <input
                  className="input"
                  type="number"
                  placeholder="0.0000"
                  value={withdrawAmount}
                  onChange={(e) => setWithdrawAmount(e.target.value)}
                />
              </div>
              <div style={{ display: 'flex', gap: '12px' }}>
                <button
                  className="btn"
                  onClick={() => withdraw(withdrawAmount)}
                  disabled={!isConnected || loading || !withdrawAmount}
                  style={{ flex: 1, opacity: !isConnected || !withdrawAmount ? 0.4 : 1 }}
                >
                  {loading ? 'PENDING...' : 'WITHDRAW'}
                </button>
                <button
                  className="btn btn-red"
                  onClick={() => exit()}
                  disabled={!isConnected || loading}
                  style={{ flex: 1, opacity: !isConnected ? 0.4 : 1 }}
                >
                  {loading ? 'PENDING...' : 'EXIT ALL'}
                </button>
              </div>
              <div style={{ marginTop: '4px', display: 'flex', flexDirection: 'column', gap: '4px' }}>
                <p style={{ fontSize: '10px', color: 'var(--text-dim)', fontFamily: 'var(--font-orbitron)', letterSpacing: '0.1em' }}>
                  WITHDRAW → only stake tokens
                </p>
                <p style={{ fontSize: '10px', color: 'var(--text-dim)', fontFamily: 'var(--font-orbitron)', letterSpacing: '0.1em' }}>
                  EXIT ALL → stake tokens + rewards
                </p>
              </div>
            </div>
          )}
        </div>

        {/* Right — Rewards */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          <div className="card" style={{ padding: '28px', flex: 1 }}>
            <span className="label">Claimable Rewards</span>
            <div style={{ margin: '16px 0 24px' }}>
              <span className="value glow-text" style={{ fontSize: '32px', color: 'var(--green)' }}>
                {fmt(earned)}
              </span>
              <span style={{ marginLeft: '8px', color: 'var(--text-dim)', fontFamily: 'var(--font-orbitron)', fontSize: '11px' }}>T11</span>
            </div>
            <button
              className="btn btn-green"
              onClick={() => claimReward()}
              disabled={!isConnected || loading || !earned}
              style={{ width: '100%', opacity: !isConnected || !earned ? 0.4 : 1 }}
            >
              {loading ? 'PENDING...' : 'CLAIM REWARDS'}
            </button>
          </div>

          <div className="card" style={{ padding: '20px' }}>
            <span className="label">Network</span>
            <div style={{ marginTop: '8px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <div style={{ width: '6px', height: '6px', borderRadius: '50%', background: 'var(--green)', boxShadow: '0 0 8px var(--green)' }} />
              <span style={{ fontFamily: 'var(--font-orbitron)', fontSize: '11px', color: 'var(--text)' }}>ANVIL LOCAL</span>
            </div>
          </div>
        </div>
      </div>
    </main>
  );
}