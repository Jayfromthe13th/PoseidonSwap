import { createConfig, http } from 'wagmi';
import { mainnet, sepolia } from 'wagmi/chains';
import { getDefaultConfig } from '@rabby-wallet/rabbykit';

// Define Umi Devnet chain
export const umiDevnet = {
  id: 42069,
  name: 'Umi Devnet',
  nativeCurrency: {
    decimals: 18,
    name: 'Ether',
    symbol: 'ETH',
  },
  rpcUrls: {
    default: {
      http: ['https://devnet.uminetwork.com'],
    },
  },
  blockExplorers: {
    default: {
      name: 'Umi Devnet Explorer',
      url: 'https://devnet.explorer.moved.network',
    },
  },
  testnet: true,
} as const;

export const config = createConfig(
  getDefaultConfig({
    appName: "PoseidonSwap",
    projectId: "58a22d2bc1c793fc31c117ad9ceba8d9", // Using example project ID for now
    chains: [umiDevnet, mainnet, sepolia],
    transports: {
      [umiDevnet.id]: http(),
      [mainnet.id]: http(),
      [sepolia.id]: http(),
    },
  })
); 