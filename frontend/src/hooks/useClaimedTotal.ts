import { useWatchContractEvent } from 'wagmi';
import { useState } from 'react';
import { formatEther } from 'viem';
import { stakingPoolAbi } from '../abi/stakingPoolAbi';
import { STAKING_POOL_ADDRESS } from '../constants/contracts';
import { useAccount } from 'wagmi';

export function useClaimedTotal() {
  const { address } = useAccount();
  const [totalClaimed, setTotalClaimed] = useState(BigInt(0));

  useWatchContractEvent({
    address: STAKING_POOL_ADDRESS,
    abi: stakingPoolAbi,
    eventName: 'Claimed',
    onLogs(logs) {
      for (const log of logs) {
        if (log.args.user?.toLowerCase() === address?.toLowerCase()) {
          setTotalClaimed(prev => prev + (log.args.amount ?? BigInt(0)));
        }
      }
    },
  });

  return {
    totalClaimed,
    totalClaimedFormatted: parseFloat(formatEther(totalClaimed)).toFixed(4),
  };
}