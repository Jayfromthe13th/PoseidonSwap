import { useConnect, useDisconnect, useAccount, useChainId, useSwitchChain } from 'wagmi';
import { injected } from 'wagmi/connectors';
import { umiDevnet } from '../lib/wagmi';
import { useEffect, useState } from 'react';

export default function WalletButton() {
  const { connect, isLoading, error } = useConnect();
  const { disconnect, isPending: isDisconnecting } = useDisconnect();
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const { switchChain } = useSwitchChain();
  
  // State to track if component has mounted (client-side)
  const [mounted, setMounted] = useState(false);

  // Set mounted to true after component mounts (client-side only)
  useEffect(() => {
    setMounted(true);
  }, []);

  // Debug logging
  console.log('WalletButton state:', { isConnected, address, chainId, isDisconnecting, mounted });

  // Don't render wallet-specific content until mounted (prevents hydration mismatch)
  if (!mounted) {
    return (
      <div className="bg-gradient-to-r from-blue-500/20 to-cyan-500/20 text-white px-4 py-2 rounded-lg backdrop-blur-lg border border-blue-500/20">
        Loading...
      </div>
    );
  }

  const handleConnect = () => {
    connect({ connector: injected() });
  };

  const handleDisconnect = async () => {
    try {
      console.log('Attempting to disconnect wallet...');
      await disconnect();
      console.log('Wallet disconnected successfully');
      
      // Force a small delay to ensure state updates
      setTimeout(() => {
        console.log('Post-disconnect state:', { isConnected, address });
        // If still connected after disconnect, try to refresh the page
        if (isConnected) {
          console.log('Still connected after disconnect, forcing page refresh...');
          window.location.reload();
        }
      }, 500);
    } catch (error) {
      console.error('Error disconnecting wallet:', error);
      // Try alternative disconnect methods
      if (window.ethereum) {
        try {
          console.log('Trying alternative disconnect method...');
          await window.ethereum.request({
            method: 'wallet_requestPermissions',
            params: [{ eth_accounts: {} }]
          });
        } catch (altError) {
          console.error('Alternative disconnect failed:', altError);
        }
      }
    }
  };

  const handleSwitchToUmi = () => {
    switchChain({ chainId: umiDevnet.id });
  };

  const isOnUmiNetwork = chainId === umiDevnet.id;

  if (isConnected) {
    return (
      <div className="flex flex-col gap-2">
        <div className="flex items-center gap-2">
          <div className="bg-blue-900/40 backdrop-blur-lg rounded-lg px-3 py-2 border border-blue-500/20">
            <span className="text-sm text-blue-200">
              {address?.slice(0, 6)}...{address?.slice(-4)}
            </span>
          </div>
          <button
            onClick={handleDisconnect}
            disabled={isDisconnecting}
            className="bg-red-500/20 hover:bg-red-500/30 text-red-300 text-sm px-3 py-2 rounded-lg backdrop-blur-lg border border-red-500/20 hover:border-red-500/40 transition-all duration-200 disabled:opacity-50"
          >
            {isDisconnecting ? 'Disconnecting...' : 'Disconnect'}
          </button>
        </div>
        
        {!isOnUmiNetwork && (
          <button
            onClick={handleSwitchToUmi}
            className="bg-orange-500/20 hover:bg-orange-500/30 text-orange-300 text-sm px-3 py-2 rounded-lg backdrop-blur-lg border border-orange-500/20 hover:border-orange-500/40 transition-all duration-200"
          >
            Switch to Umi Devnet
          </button>
        )}
        
        {isOnUmiNetwork && (
          <div className="text-xs text-green-400 text-center">
            ✓ Connected to Umi Devnet
          </div>
        )}
      </div>
    );
  }

  return (
    <button
      onClick={handleConnect}
      disabled={isLoading}
      className="bg-gradient-to-r from-blue-500/20 to-cyan-500/20 hover:from-blue-500/30 hover:to-cyan-500/30 text-white px-4 py-2 rounded-lg backdrop-blur-lg border border-blue-500/20 hover:border-blue-500/40 transition-all duration-200 disabled:opacity-50"
    >
      {isLoading ? 'Connecting...' : 'Connect Wallet'}
    </button>
  );
} 