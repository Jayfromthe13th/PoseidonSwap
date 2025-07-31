import { createConfig, http } from 'wagmi';
import { injected } from 'wagmi/connectors';

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

// Create a simple Rabby-only connector
const rabbyConnector = injected({
  target: () => ({
    id: 'rabby',
    name: 'Rabby Wallet',
    provider: typeof window !== 'undefined' ? window.ethereum : undefined,
  }),
});

// Configure wagmi for Rabby only
export const config = createConfig({
  chains: [umiDevnet],
  connectors: [rabbyConnector],
  transports: {
    [umiDevnet.id]: http(),
  },
}); 