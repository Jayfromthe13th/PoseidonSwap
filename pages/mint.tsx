import { useState, useEffect } from 'react';
import { ArrowLeftIcon } from '@heroicons/react/24/solid';
import { useAccount, useChainId } from 'wagmi';
import { useRouter } from 'next/router';
import WalletButton from '../components/WalletButton';
import { umiDevnet } from '../lib/wagmi';
import { mintUMITokens, getUMIBalance } from '../lib/contractUtils';

// Custom SVG components (reused from main page)
const TridentIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" className="w-8 h-8 fill-current opacity-70">
    <path d="M12 2c-.5 0-1 .4-1 1v2.7L9.2 4.8c-.4-.4-1-.4-1.4 0-.4.4-.4 1 0 1.4L9.2 7.6 8.5 8.3 7.8 7.6l1.4-1.4c.4-.4.4-1 0-1.4-.4-.4-1-.4-1.4 0L6.5 6.1V3c0-.6-.4-1-1-1s-1 .4-1 1v7c0 .6.4 1 1 1h7c.6 0 1-.4 1-1V3c0-.6-.4-1-1-1zm0 0M20.5 3c-.6 0-1 .4-1 1v3.1l-1.4-1.4c-.4-.4-1-.4-1.4 0-.4.4-.4 1 0 1.4l1.4 1.4-.7.7-.7-.7 1.4-1.4c.4-.4.4-1 0-1.4-.4-.4-1-.4-1.4 0l-1.4 1.4V3c0-.6-.4-1-1-1s-1 .4-1 1v7c0 .6.4 1 1 1h7c.6 0 1-.4 1-1V3c0-.6-.4-1-1-1z"/>
    <path d="M12 11v11c0 .6.4 1 1 1s1-.4 1-1V11h-2z"/>
  </svg>
);

const CoinsIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" className="w-6 h-6 fill-current">
    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
  </svg>
);

export default function MintPage() {
  const [mintAmount, setMintAmount] = useState('');
  const [mounted, setMounted] = useState(false);
  const [currentBalance, setCurrentBalance] = useState('0');
  const [isLoading, setIsLoading] = useState(false);
  
  const { isConnected, address } = useAccount();
  const chainId = useChainId();
  const router = useRouter();
  const isOnUmiNetwork = chainId === umiDevnet.id;

  useEffect(() => {
    setMounted(true);
  }, []);

  useEffect(() => {
    if (mounted) {
      fetchBalance();
    }
  }, [isConnected, address, mounted]);

  const fetchBalance = async () => {
    if (isConnected && address && mounted) {
      try {
        const balance = await getUMIBalance(address);
        setCurrentBalance(balance);
      } catch (error) {
        console.error('Error fetching balance:', error);
        setCurrentBalance('0');
      }
    }
  };

  const handleMint = async () => {
    if (!isConnected) {
      alert('Please connect your wallet first');
      return;
    }
    
    if (!isOnUmiNetwork) {
      alert('Please switch to Umi Devnet');
      return;
    }

    if (!mintAmount || parseFloat(mintAmount) <= 0) {
      alert('Please enter a valid amount');
      return;
    }
    
    setIsLoading(true);
    
    try {
      // Call the actual mint function
      const txHash = await mintUMITokens(mintAmount, address!);
      
      // Update balance after successful mint
      await fetchBalance();
      
      // Show success message
      alert(`✅ Successfully minted ${mintAmount} UMI tokens!\nTransaction: ${txHash}`);
      
      // Clear the input
      setMintAmount('');
      
    } catch (error) {
      console.error('Minting failed:', error);
      alert(`❌ Failed to mint UMI tokens: ${error.message || error}`);
    } finally {
      setIsLoading(false);
    }
  };

  const handlePresetAmount = (amount: string) => {
    setMintAmount(amount);
  };

  const getMintButtonText = () => {
    if (!mounted) return 'Loading...';
    if (isLoading) return 'Minting...';
    if (!isConnected) return 'Connect Wallet to Mint';
    if (!isOnUmiNetwork) return 'Switch to Umi Devnet';
    return 'Mint UMI Tokens';
  };

  const isMintDisabled = !mounted || isLoading || !isConnected || !isOnUmiNetwork || !mintAmount || parseFloat(mintAmount) <= 0;

  return (
    <div className="min-h-screen bg-blue-950 text-white flex items-center justify-center p-4 relative overflow-hidden">
      {/* Wallet Button - Top Right */}
      <div className="fixed top-6 right-6 z-20">
        <WalletButton />
      </div>

      {/* Back Button - Top Left */}
      <div className="fixed top-6 left-6 z-20">
        <button
          onClick={() => router.push('/')}
          className="bg-blue-600/80 p-3 rounded-xl hover:bg-blue-500/80 transition-all duration-200 shadow-lg hover:shadow-blue-500/25 transform hover:scale-110 backdrop-blur-sm flex items-center gap-2"
        >
          <ArrowLeftIcon className="h-5 w-5 text-white" />
          <span className="text-sm font-medium">Back to Swap</span>
        </button>
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
      <div className="fixed top-10 left-1/4 text-blue-400/20 animate-pulse">
        <TridentIcon />
      </div>
      <div className="fixed bottom-10 right-1/4 text-blue-400/20 animate-pulse" style={{ animationDelay: '1s' }}>
        <CoinsIcon />
      </div>
      
      <div className="w-full max-w-md bg-gradient-to-b from-blue-800/10 to-blue-900/10 backdrop-blur-xl rounded-3xl p-8 shadow-2xl border border-blue-500/20 relative z-10 content-glow">
        <div className="flex items-center justify-center gap-3 mb-8">
          <CoinsIcon />
          <h1 className="text-3xl font-bold text-center bg-gradient-to-r from-blue-400 to-cyan-400 text-transparent bg-clip-text">
            Mint UMI Tokens
          </h1>
          <TridentIcon />
        </div>

        {/* Current Balance */}
        <div className="bg-blue-900/20 rounded-2xl p-4 mb-6 backdrop-blur-lg border border-blue-500/20">
          <div className="text-center">
            <label className="text-blue-200 text-sm">Current UMI Balance</label>
            <div className="text-2xl font-bold text-white mt-1">{currentBalance} UMI</div>
          </div>
        </div>
        
        {/* Mint Amount Input */}
        <div className="bg-blue-900/20 rounded-2xl p-4 mb-4 backdrop-blur-lg border border-blue-500/20 hover:border-blue-500/40 transition-all duration-200">
          <div className="flex justify-between mb-2">
            <label className="text-blue-200">Amount to Mint</label>
            <span className="text-blue-200 text-sm">UMI</span>
          </div>
          <input
            type="number"
            placeholder="Enter amount"
            className="w-full bg-transparent text-2xl outline-none placeholder-blue-300/50 focus:placeholder-blue-300/30 transition-colors"
            value={mintAmount}
            onChange={(e) => setMintAmount(e.target.value)}
          />
        </div>

        {/* Preset Amount Buttons */}
        <div className="grid grid-cols-3 gap-3 mb-6">
          {['100', '1000', '10000'].map((amount) => (
            <button
              key={amount}
              onClick={() => handlePresetAmount(amount)}
              className="bg-blue-700/30 hover:bg-blue-600/40 text-blue-200 hover:text-white py-3 px-4 rounded-xl transition-all duration-200 border border-blue-500/30 hover:border-blue-500/50 text-sm font-medium"
            >
              {amount} UMI
            </button>
          ))}
        </div>

        {/* Mint Button */}
        <button
          onClick={handleMint}
          disabled={isMintDisabled}
          className={`w-full font-bold py-4 px-4 rounded-xl transition-all duration-200 shadow-lg transform hover:scale-[1.02] backdrop-blur-sm ${
            isMintDisabled
              ? 'bg-gray-500/20 text-gray-400 cursor-not-allowed'
              : 'bg-gradient-to-r from-green-500/80 to-emerald-500/80 hover:from-green-600/80 hover:to-emerald-600/80 text-white hover:shadow-green-500/25'
          }`}
        >
          {getMintButtonText()}
        </button>

        {/* Info Text */}
        <div className="mt-4 text-center text-sm text-blue-300/70">
          Mint UMI tokens for testing on devnet
        </div>
        
        {/* Connection Status */}
        {mounted && isConnected && (
          <div className="mt-2 text-center text-xs text-blue-300/50">
            {isOnUmiNetwork ? '✓ Ready to mint on Umi Devnet' : 'Switch to Umi Devnet to mint'}
          </div>
        )}
      </div>
    </div>
  );
} 