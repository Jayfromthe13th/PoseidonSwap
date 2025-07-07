import { useWallet } from './WalletProvider';

export function WalletButton() {
  const { 
    isConnected, 
    address, 
    chainId, 
    isConnecting, 
    connectWallet, 
    disconnectWallet,
    switchToUmiDevnet 
  } = useWallet();

  const formatAddress = (addr: string) => {
    return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
  };

  const isOnUmiDevnet = chainId === 42069; // Umi devnet chain ID
  
  // Debug logging
  console.log('WalletButton - Current chainId:', chainId, 'isOnUmiDevnet:', isOnUmiDevnet);

  if (isConnected && address) {
    return (
      <div className="flex flex-col gap-2 items-end">
        {/* Top row: Network indicator and address */}
        <div className="flex items-center gap-2">
          {/* Network indicator */}
          <div className={`px-2 py-1 rounded-lg text-xs font-medium ${
            isOnUmiDevnet 
              ? 'bg-green-500/20 text-green-400 border border-green-500/30' 
              : 'bg-orange-500/20 text-orange-400 border border-orange-500/30'
          }`}>
            {isOnUmiDevnet ? 'Umi Devnet' : `Chain ${chainId}`}
          </div>
          
          {/* Address display */}
          <div className="px-3 py-2 bg-blue-900/20 text-blue-200 rounded-lg border border-blue-500/20 text-sm font-mono">
            {formatAddress(address)}
          </div>
        </div>
        
        {/* Bottom row: Action buttons */}
        <div className="flex items-center gap-2">
          {/* Switch to Umi button if not on Umi */}
          {!isOnUmiDevnet && (
            <button
              onClick={switchToUmiDevnet}
              className="px-3 py-1 bg-blue-500/20 hover:bg-blue-500/30 text-blue-400 text-xs rounded-lg border border-blue-500/30 transition-colors"
            >
              Switch to Umi
            </button>
          )}
          
          {/* Disconnect button */}
          <button
            onClick={disconnectWallet}
            className="px-3 py-1 bg-red-500/20 hover:bg-red-500/30 text-red-400 text-xs rounded-lg border border-red-500/30 transition-colors"
          >
            Disconnect
          </button>
        </div>
      </div>
    );
  }

  return (
    <button
      onClick={connectWallet}
      disabled={isConnecting}
      className="px-6 py-3 bg-gradient-to-r from-blue-500/80 to-cyan-500/80 hover:from-blue-600/80 hover:to-cyan-600/80 text-white font-bold rounded-xl transition-all duration-200 shadow-lg hover:shadow-blue-500/25 transform hover:scale-[1.02] backdrop-blur-sm disabled:opacity-50 disabled:cursor-not-allowed"
    >
      {isConnecting ? (
        <div className="flex items-center gap-2">
          <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
          Connecting...
        </div>
      ) : (
        'Connect Rabby Wallet'
      )}
    </button>
  );
} 