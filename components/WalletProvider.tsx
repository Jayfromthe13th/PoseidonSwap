'use client';

import { createContext, useContext, useEffect, useState } from 'react';
import { createConfig, connect, disconnect, getAccount, watchAccount } from '@wagmi/core';
import { injected } from '@wagmi/connectors';
import { http } from 'viem';
import { mainnet, sepolia } from 'viem/chains';

// Define Umi devnet chain - Updated with correct details
const umiDevnet = {
  id: 42069, // Correct Umi Devnet Chain ID
  name: 'Umi Devnet',
  network: 'umi-devnet',
  nativeCurrency: {
    decimals: 18,
    name: 'Ethereum',
    symbol: 'ETH', // Correct currency symbol
  },
  rpcUrls: {
    default: {
      http: ['https://devnet.uminetwork.com'],
    },
    public: {
      http: ['https://devnet.uminetwork.com'],
    },
  },
  blockExplorers: {
    default: { name: 'Umi Explorer', url: 'https://devnet.explorer.moved.network' }, // Correct explorer URL
  },
} as const;

// Create wagmi config
const config = createConfig({
  chains: [umiDevnet, mainnet, sepolia],
  connectors: [injected()],
  transports: {
    [umiDevnet.id]: http(),
    [mainnet.id]: http(),
    [sepolia.id]: http(),
  },
});

interface WalletContextType {
  isConnected: boolean;
  address: string | undefined;
  chainId: number | undefined;
  balance: string;
  isConnecting: boolean;
  connectWallet: () => Promise<void>;
  disconnectWallet: () => Promise<void>;
  switchToUmiDevnet: () => Promise<void>;
}

const WalletContext = createContext<WalletContextType | undefined>(undefined);

export function WalletProvider({ children }: { children: React.ReactNode }) {
  const [isConnected, setIsConnected] = useState(false);
  const [address, setAddress] = useState<string | undefined>(undefined);
  const [chainId, setChainId] = useState<number | undefined>(undefined);
  const [balance, setBalance] = useState('0');
  const [isConnecting, setIsConnecting] = useState(false);

  useEffect(() => {
    // Check initial connection state
    const account = getAccount(config);
    console.log('Initial account state:', account);
    setIsConnected(account.isConnected);
    setAddress(account.address);
    setChainId(account.chainId);

    // Watch for account changes
    const unwatch = watchAccount(config, {
      onChange(account) {
        console.log('Account changed:', account);
        setIsConnected(account.isConnected);
        setAddress(account.address);
        setChainId(account.chainId);
      },
    });

    return () => unwatch();
  }, []);

  const connectWallet = async () => {
    try {
      setIsConnecting(true);
      
      // Check if any wallet is installed
      if (typeof window !== 'undefined' && window.ethereum) {
        console.log('Attempting to connect wallet...');
        
        // Try to connect using the injected connector
        const result = await connect(config, {
          connector: injected(),
        });
        
        console.log('Connected successfully:', result);
      } else {
        // No wallet detected, redirect to Rabby download page
        alert('No wallet detected. Please install Rabby Wallet or another Web3 wallet.');
        window.open('https://rabby.io/', '_blank');
      }
    } catch (error) {
      console.error('Failed to connect wallet:', error);
      alert('Failed to connect wallet. Please make sure your wallet is unlocked and try again.');
    } finally {
      setIsConnecting(false);
    }
  };

  const disconnectWallet = async () => {
    try {
      console.log('Disconnecting wallet...');
      await disconnect(config);
      console.log('Wallet disconnected successfully');
      
      // Force update the state
      setIsConnected(false);
      setAddress(undefined);
      setChainId(undefined);
    } catch (error) {
      console.error('Failed to disconnect wallet:', error);
      alert('Failed to disconnect wallet. Please try again.');
    }
  };

  const switchToUmiDevnet = async () => {
    try {
      if (!window.ethereum) {
        alert('No wallet detected. Please install a Web3 wallet.');
        return;
      }

      console.log('Attempting to switch to Umi Devnet (Chain ID: 42069)...');
      const chainIdHex = `0x${umiDevnet.id.toString(16)}`; // 0xa4b5
      console.log('Chain ID hex:', chainIdHex);

      await window.ethereum.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: chainIdHex }],
      });
      
      console.log('Successfully switched to Umi Devnet');
    } catch (error: any) {
      console.error('Failed to switch network:', error);
      
      // Error code 4902 means the chain is not added to the wallet
      if (error.code === 4902) {
        console.log('Network not found, attempting to add Umi Devnet...');
        try {
          await window.ethereum?.request({
            method: 'wallet_addEthereumChain',
            params: [
              {
                chainId: `0x${umiDevnet.id.toString(16)}`,
                chainName: umiDevnet.name,
                nativeCurrency: umiDevnet.nativeCurrency,
                rpcUrls: umiDevnet.rpcUrls.default.http,
                blockExplorerUrls: [umiDevnet.blockExplorers.default.url],
              },
            ],
          });
          console.log('Successfully added Umi Devnet to wallet');
        } catch (addError) {
          console.error('Failed to add network:', addError);
          alert('Failed to add Umi Devnet to your wallet. Please add it manually.');
        }
      } else {
        alert('Failed to switch to Umi Devnet. Please check your wallet.');
      }
    }
  };

  const value: WalletContextType = {
    isConnected,
    address,
    chainId,
    balance,
    isConnecting,
    connectWallet,
    disconnectWallet,
    switchToUmiDevnet,
  };

  return (
    <WalletContext.Provider value={value}>
      {children}
    </WalletContext.Provider>
  );
}

export function useWallet() {
  const context = useContext(WalletContext);
  if (context === undefined) {
    throw new Error('useWallet must be used within a WalletProvider');
  }
  return context;
}

// Global type extension for window.ethereum
declare global {
  interface Window {
    ethereum?: any;
  }
} 