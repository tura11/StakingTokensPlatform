import { useReadContract, useAccount } from 'wagmi';
import { stakingPoolAbi } from '../abi/stakingPoolAbi';
import { STAKING_POOL_ADDRESS } from '../constants/contracts';

export function useStakingPool() {
  const { address } = useAccount();

  const { data: totalSupply } = useReadContract({
    address: STAKING_POOL_ADDRESS,
    abi: stakingPoolAbi,
    functionName: 'getTotalSupply',
    query: { 
      refetchInterval: 5000,
    },
  });

  const { data: userBalance } = useReadContract({
    address: STAKING_POOL_ADDRESS,
    abi: stakingPoolAbi,
    functionName: 'getUserBalance',
    args: [address!],
    query: { 
      enabled: !!address,
      refetchInterval: 5000,
    },
  });

  const { data: earned } = useReadContract({
    address: STAKING_POOL_ADDRESS,
    abi: stakingPoolAbi,
    functionName: 'earned',
    args: [address!],
    query: { 
      enabled: !!address,
      refetchInterval: 5000, 
    },
  });

  const { data: rewardRate } = useReadContract({
    address: STAKING_POOL_ADDRESS,
    abi: stakingPoolAbi,
    functionName: 'getRewardRate',
  });

  const { data: periodFinish } = useReadContract({
    address: STAKING_POOL_ADDRESS,
    abi: stakingPoolAbi,
    functionName: 'getPeriodFinish',
  });

  return {
    totalSupply,
    userBalance,
    earned,
    rewardRate,
    periodFinish,
  };
}