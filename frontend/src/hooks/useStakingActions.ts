import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseEther } from 'viem';
import { stakingPoolAbi } from '../abi/stakingPoolAbi';
import { erc20Abi } from '../abi/erc20Abi';
import { STAKING_POOL_ADDRESS, STAKE_TOKEN_ADDRESS } from '../constants/contracts';

export function useStakingActions() {
  const { writeContract, data: hash, isPending } = useWriteContract();

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  const approve = (amount: string) => {
    writeContract({
      address: STAKE_TOKEN_ADDRESS,
      abi: erc20Abi,
      functionName: 'approve',
      args: [STAKING_POOL_ADDRESS, parseEther(amount)],
    });
  };

  const stake = (amount: string) => {
    writeContract({
      address: STAKING_POOL_ADDRESS,
      abi: stakingPoolAbi,
      functionName: 'stake',
      args: [parseEther(amount)],
    });
  };

  const withdraw = (amount: string) => {
    writeContract({
      address: STAKING_POOL_ADDRESS,
      abi: stakingPoolAbi,
      functionName: 'withdraw',
      args: [parseEther(amount)],
    });
  };

  const claimReward = () => {
    writeContract({
      address: STAKING_POOL_ADDRESS,
      abi: stakingPoolAbi,
      functionName: 'claimReward',
    });
  };

  const exit = () => {
    writeContract({
      address: STAKING_POOL_ADDRESS,
      abi: stakingPoolAbi,
      functionName: 'exit',
    });
  };

  return {
    approve,
    stake,
    withdraw,
    claimReward,
    exit,
    isPending,
    isConfirming,
    isSuccess,
    hash,
  };
}