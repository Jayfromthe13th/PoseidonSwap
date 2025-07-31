import { useEffect, useState } from 'react';

// Global type extension for wallet
declare global {
  interface Window {
    ethereum?: {
      request?: (...args: any[]) => Promise<any>;
      on?: (event: string, handler: (...args: any[]) => void) => void;
      removeListener?: (event: string, handler: (...args: any[]) => void) => void;
    };
  }
}

export default function WalletButton() {
  // Only use local state - no wagmi hooks that might trigger wallet selection
  const [directAddress, setDirectAddress] = useState<string>('');
  const [isConnecting, setIsConnecting] = useState(false);
  const [isDisconnecting, setIsDisconnecting] = useState(false);
  const [currentChainId, setCurrentChainId] = useState<number>(42069);

  useEffect(() => {
    console.log('WalletButton initialized');
    
    // Wait for wallet extensions to fully load
    const initWallet = async () => {
      // Wait a bit for extensions to inject
      await new Promise(resolve => setTimeout(resolve, 100));
      
      // Check if already connected - use try/catch to handle conflicts
      if (typeof window !== 'undefined' && window.ethereum) {
        try {
          // Check existing connection
          const accounts = await window.ethereum.request({ method: 'eth_accounts' });
          if (accounts && accounts.length > 0) {
            setDirectAddress(accounts[0]);
            console.log('Already connected to:', accounts[0]);
          }
          
          // Check current chain
          const chainId = await window.ethereum.request({ method: 'eth_chainId' });
          if (chainId) {
            setCurrentChainId(parseInt(chainId, 16));
          }
        } catch (error) {
          console.warn('Wallet initialization error (this is normal with multiple extensions):', error);
          // Don't throw - just continue without auto-connection
        }
      }
    };
    
    initWallet();
  }, []);

  // Debug logging
  console.log('WalletButton state:', { 
    directAddress,
    currentChainId,
    isDisconnecting, 
    isConnecting
  });

  const handleDirectConnect = async () => {
    console.log('🔗 Direct wallet connect clicked!');
    setIsConnecting(true);
    
    try {
      if (typeof window === 'undefined' || !window.ethereum) {
        throw new Error('No wallet detected. Please install a wallet extension (MetaMask, Rabby, etc.)');
      }

      console.log('Requesting accounts from wallet...');
      
      // Use a more robust approach to handle wallet conflicts
      let accounts;
      try {
        accounts = await window.ethereum.request({
          method: 'eth_requestAccounts'
        });
      } catch (requestError: any) {
        // If there's a conflict, try to use the ethereum object anyway
        if (requestError.message?.includes('redefine') || requestError.message?.includes('ethereum')) {
          console.warn('Wallet conflict detected, trying alternative approach...');
          // Give it a moment and try again
          await new Promise(resolve => setTimeout(resolve, 200));
          accounts = await window.ethereum.request({
            method: 'eth_requestAccounts'
          });
        } else {
          throw requestError;
        }
      }
      
      if (accounts && accounts.length > 0) {
        setDirectAddress(accounts[0]);
        console.log('✅ Connected to:', accounts[0]);
        
        // Try to switch to UMI Devnet
        try {
          await window.ethereum.request({
            method: 'wallet_switchEthereumChain',
            params: [{ chainId: '0xA455' }], // 42069 in hex
          });
          setCurrentChainId(42069);
        } catch (switchError: any) {
          // If chain doesn't exist, add it
          if (switchError.code === 4902) {
            await window.ethereum.request({
              method: 'wallet_addEthereumChain',
              params: [{
                chainId: '0xA455',
                chainName: 'Umi Devnet',
                nativeCurrency: {
                  name: 'Ether',
                  symbol: 'ETH',
                  decimals: 18,
                },
                rpcUrls: ['https://devnet.uminetwork.com'],
                blockExplorerUrls: ['https://devnet.explorer.moved.network'],
              }],
            });
            setCurrentChainId(42069);
          }
        }
      } else {
        throw new Error('No accounts returned');
      }
    } catch (error: any) {
      console.error('❌ Connection failed:', error);
      alert(`Connection failed: ${error.message}`);
    } finally {
      setIsConnecting(false);
    }
  };

  const handleDirectDisconnect = () => {
    console.log('Disconnecting...');
    setDirectAddress('');
    setIsDisconnecting(false);
  };

  const handleSwitchToUmi = async () => {
    try {
      await window.ethereum?.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: '0xA455' }], // 42069 in hex
      });
      setCurrentChainId(42069);
    } catch (error) {
      console.error('Failed to switch chain:', error);
    }
  };

  const isOnUmiNetwork = currentChainId === 42069;

  if (directAddress) {
    return (
      <div className="flex flex-col gap-2">
        <div className="flex items-center gap-2">
          <div className="bg-blue-900/40 backdrop-blur-lg rounded-lg px-3 py-2 border border-blue-500/20">
            <span className="text-sm text-blue-200">
              {directAddress?.slice(0, 6)}...{directAddress?.slice(-4)}
            </span>
          </div>
          <button
            onClick={handleDirectDisconnect}
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
      onClick={handleDirectConnect}
      disabled={isConnecting}
      className="bg-gradient-to-r from-blue-500/20 to-cyan-500/20 hover:from-blue-500/30 hover:to-cyan-500/30 text-white px-4 py-2 rounded-lg backdrop-blur-lg border border-blue-500/20 hover:border-blue-500/40 transition-all duration-200 disabled:opacity-50"
    >
{isConnecting ? 'Connecting...' : 'Connect Wallet'}
    </button>
  );
} 