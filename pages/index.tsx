import { useState, useEffect } from 'react';
import { ArrowDownIcon } from '@heroicons/react/24/solid';
import { useAccount, useChainId } from 'wagmi';
import WalletButton from '../components/WalletButton';
import { umiDevnet } from '../lib/wagmi';
import { swapUMIForShell, getUMIBalance } from '../lib/contractUtils';

// Custom SVG components
const TridentIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" className="w-8 h-8 fill-current opacity-70">
    <path d="M12 2c-.5 0-1 .4-1 1v2.7L9.2 4.8c-.4-.4-1-.4-1.4 0-.4.4-.4 1 0 1.4L9.2 7.6 8.5 8.3 7.8 7.6l1.4-1.4c.4-.4.4-1 0-1.4-.4-.4-1-.4-1.4 0L6.5 6.1V3c0-.6-.4-1-1-1s-1 .4-1 1v7c0 .6.4 1 1 1h7c.6 0 1-.4 1-1V3c0-.6-.4-1-1-1zm0 0M20.5 3c-.6 0-1 .4-1 1v3.1l-1.4-1.4c-.4-.4-1-.4-1.4 0-.4.4-.4 1 0 1.4l1.4 1.4-.7.7-.7-.7 1.4-1.4c.4-.4.4-1 0-1.4-.4-.4-1-.4-1.4 0l-1.4 1.4V3c0-.6-.4-1-1-1s-1 .4-1 1v7c0 .6.4 1 1 1h7c.6 0 1-.4 1-1V3c0-.6-.4-1-1-1z"/>
    <path d="M12 11v11c0 .6.4 1 1 1s1-.4 1-1V11h-2z"/>
  </svg>
);

const SeashellIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" className="w-8 h-8 fill-current opacity-70">
    <path d="M19.9 12.6c.1-.4.1-.8.1-1.2 0-3.3-2.7-6-6-6-1.9 0-3.6.9-4.7 2.3C8.2 6.5 6.5 5.8 4.6 6 2.4 6.3.7 8.2.7 10.4c0 1.7 1 3.2 2.5 3.9.3.1.5.2.8.2h1.6c.4 1.9 2.1 3.3 4.1 3.3.8 0 1.6-.2 2.2-.7.6.4 1.4.7 2.2.7 2.3 0 4.2-1.9 4.2-4.2 0-.4-.1-.7-.2-1.1.7-.3 1.3-.8 1.8-1.4.3.7.5 1.5.5 2.3 0 3.3-2.7 6-6 6-1.9 0-3.6-.9-4.7-2.3-1.1 1.4-2.8 2.3-4.7 2.3-.4 0-.8 0-1.2-.1-.4-.1-.7.2-.8.6-.1.4.2.7.6.8.5.1 1 .2 1.4.2 2.2 0 4.2-1 5.6-2.6 1.4 1.6 3.4 2.6 5.6 2.6 4.1 0 7.5-3.4 7.5-7.5 0-1.5-.4-2.9-1.2-4.1z"/>
  </svg>
);

export default function SwapInterface() {
  const [fromAmount, setFromAmount] = useState('');
  const [toAmount, setToAmount] = useState('');
  const [fromToken, setFromToken] = useState('UMI');
  const [toToken, setToToken] = useState('SHELL');
  const [mounted, setMounted] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [umiBalance, setUmiBalance] = useState('0');
  
  const { isConnected, address } = useAccount();
  const chainId = useChainId();
  const isOnUmiNetwork = chainId === umiDevnet.id;

  useEffect(() => {
    setMounted(true);
  }, []);

  useEffect(() => {
    if (mounted) {
      fetchBalance();
    }
  }, [isConnected, address, mounted]);

  useEffect(() => {
    // Calculate estimated output when fromAmount changes
    if (fromAmount && fromToken === 'UMI') {
      const estimatedShell = (parseFloat(fromAmount) * 0.00234).toFixed(6);
      setToAmount(estimatedShell);
    } else {
      setToAmount('');
    }
  }, [fromAmount, fromToken]);

  const fetchBalance = async () => {
    if (isConnected && address && mounted) {
      try {
        const balance = await getUMIBalance(address);
        setUmiBalance(balance);
      } catch (error) {
        console.error('Error fetching balance:', error);
        setUmiBalance('0');
      }
    }
  };

  const handleSwap = async () => {
    if (!isConnected) {
      alert('Please connect your wallet first');
      return;
    }
    
    if (!isOnUmiNetwork) {
      alert('Please switch to Umi Devnet');
      return;
    }

    if (!fromAmount || parseFloat(fromAmount) <= 0) {
      alert('Please enter a valid amount');
      return;
    }

    if (fromToken !== 'UMI') {
      alert('Currently only UMI → SHELL swaps are supported');
      return;
    }
    
    setIsLoading(true);
    
    try {
      // Call the actual swap function
      const txHash = await swapUMIForShell(fromAmount, address!);
      
      // Update balance after successful swap
      await fetchBalance();
      
      // Show success message
      alert(`✅ Successfully swapped ${fromAmount} UMI for ${toAmount} SHELL!\nTransaction: ${txHash}`);
      
      // Clear the inputs
      setFromAmount('');
      setToAmount('');
      
    } catch (error) {
      console.error('Swap failed:', error);
      alert(`❌ Failed to swap tokens: ${error.message || error}`);
    } finally {
      setIsLoading(false);
    }
  };

  const getSwapButtonText = () => {
    if (!mounted) return 'Loading...';
    if (isLoading) return 'Swapping...';
    if (!isConnected) return 'Connect Wallet to Swap';
    if (!isOnUmiNetwork) return 'Switch to Umi Devnet';
    return 'Swap';
  };

  const isSwapDisabled = !mounted || isLoading || !isConnected || !isOnUmiNetwork || !fromAmount || parseFloat(fromAmount) <= 0;

  return (
    <div className="min-h-screen bg-blue-950 text-white flex items-center justify-center p-4 relative overflow-hidden">
      {/* Wallet Button - Top Right */}
      <div className="fixed top-6 right-6 z-20">
        <WalletButton />
      </div>

      {/* Animated Background */}
      <div className="absolute inset-0 overflow-hidden">
        {/* Wave Container */}
        <div className="wave-container">
          <div className="wave"></div>
          <div className="wave2"></div>
          <div className="wave3"></div>
        </div>
      </div>

      {/* Decorative Background Elements */}
      <div className="fixed top-10 left-10 text-blue-400/20 animate-pulse">
        <TridentIcon />
      </div>
      <div className="fixed bottom-10 right-10 text-blue-400/20 animate-pulse" style={{ animationDelay: '1s' }}>
        <SeashellIcon />
      </div>
      
      <div className="w-full max-w-md bg-gradient-to-b from-blue-800/10 to-blue-900/10 backdrop-blur-xl rounded-3xl p-8 shadow-2xl border border-blue-500/20 relative z-10 content-glow">
        <div className="flex items-center justify-center gap-3 mb-8">
          <TridentIcon />
          <h1 className="text-3xl font-bold text-center bg-gradient-to-r from-blue-400 to-cyan-400 text-transparent bg-clip-text">
            PoseidonSwap
          </h1>
          <SeashellIcon />
        </div>
        
        {/* From Token */}
        <div className="bg-blue-900/20 rounded-2xl p-4 mb-2 backdrop-blur-lg border border-blue-500/20 hover:border-blue-500/40 transition-all duration-200">
          <div className="flex justify-between mb-2">
            <label className="text-blue-200">From</label>
            <div className="flex items-center gap-2">
              {mounted && isConnected && fromToken === 'UMI' && (
                <span className="text-xs text-blue-300/70">Balance: {umiBalance}</span>
              )}
              <select 
                className="bg-transparent text-right outline-none text-blue-200 hover:text-blue-100 transition-colors cursor-pointer"
                value={fromToken}
                onChange={(e) => setFromToken(e.target.value)}
              >
                <option value="UMI" className="bg-blue-900">UMI</option>
                <option value="SHELL" className="bg-blue-900">SHELL</option>
              </select>
            </div>
          </div>
          <input
            type="number"
            placeholder="0.0"
            className="w-full bg-transparent text-2xl outline-none placeholder-blue-300/50 focus:placeholder-blue-300/30 transition-colors"
            value={fromAmount}
            onChange={(e) => setFromAmount(e.target.value)}
          />
        </div>

        {/* Swap Icon */}
        <div className="flex justify-center -my-2 relative z-10">
          <button 
            className="bg-blue-600/80 p-3 rounded-xl hover:bg-blue-500/80 transition-all duration-200 shadow-lg hover:shadow-blue-500/25 transform hover:scale-110 backdrop-blur-sm"
            onClick={() => {
              setFromToken(toToken);
              setToToken(fromToken);
              setFromAmount(toAmount);
              setToAmount(fromAmount);
            }}
          >
            <ArrowDownIcon className="h-5 w-5 text-white" />
          </button>
        </div>

        {/* To Token */}
        <div className="bg-blue-900/20 rounded-2xl p-4 mb-6 backdrop-blur-lg border border-blue-500/20 hover:border-blue-500/40 transition-all duration-200">
          <div className="flex justify-between mb-2">
            <label className="text-blue-200">To</label>
            <select 
              className="bg-transparent text-right outline-none text-blue-200 hover:text-blue-100 transition-colors cursor-pointer"
              value={toToken}
              onChange={(e) => setToToken(e.target.value)}
            >
              <option value="SHELL" className="bg-blue-900">SHELL</option>
              <option value="UMI" className="bg-blue-900">UMI</option>
            </select>
          </div>
          <input
            type="number"
            placeholder="0.0"
            className="w-full bg-transparent text-2xl outline-none placeholder-blue-300/50 focus:placeholder-blue-300/30 transition-colors"
            value={toAmount}
            onChange={(e) => setToAmount(e.target.value)}
          />
        </div>

        {/* Swap Button */}
        <button
          onClick={handleSwap}
          disabled={isSwapDisabled}
          className={`w-full font-bold py-4 px-4 rounded-xl transition-all duration-200 shadow-lg transform hover:scale-[1.02] backdrop-blur-sm ${
            isSwapDisabled
              ? 'bg-gray-500/20 text-gray-400 cursor-not-allowed'
              : 'bg-gradient-to-r from-blue-500/80 to-cyan-500/80 hover:from-blue-600/80 hover:to-cyan-600/80 text-white hover:shadow-blue-500/25'
          }`}
        >
          {getSwapButtonText()}
        </button>

        {/* Exchange Rate */}
        <div className="mt-4 text-center text-sm text-blue-300/70">
          1 UMI = 0.00234 SHELL
        </div>

        {/* Need Tokens Link */}
        <div className="mt-3 text-center">
          <a 
            href="/mint"
            className="text-sm text-blue-400 hover:text-blue-300 underline transition-colors"
          >
            Need UMI tokens? Mint here →
          </a>
        </div>
        
        {/* Connection Status */}
        {mounted && isConnected && (
          <div className="mt-2 text-center text-xs text-blue-300/50">
            {isOnUmiNetwork ? '✓ Ready to swap on Umi Devnet' : '⚠️ Switch to Umi Devnet to swap'}
          </div>
        )}
      </div>
    </div>
  );
} 