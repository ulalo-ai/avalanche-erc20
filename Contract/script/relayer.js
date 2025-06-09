require("dotenv").config();
const { ethers } = require("ethers");

const FUJI_LOCKER_ADDRESS = "0xFujiLocker"; // Replace
const ULALO_MINTER_ADDRESS = "0xUlaloMinter"; // Replace

// Updated ABIs to include native coin events and functions
const LOCK_ABI = [
  // Token events
  "event TokenLocked(address indexed token, address indexed sender, uint256 amount, bytes32 indexed txId)",
  "event TokenUnlocked(address indexed token, address indexed recipient, uint256 amount)",
  "function unlockToken(address token, address to, uint256 amount) external",
  
  // Native coin events
  "event NativeCoinLocked(address indexed sender, uint256 amount, bytes32 indexed txId)",
  "event NativeCoinUnlocked(address indexed recipient, uint256 amount)",
  "function unlockNativeCoin(address payable to, uint256 amount) external"
];

const MINTER_ABI = [
  // Token functions and events
  "function mintWrapped(address originalToken, address to, uint256 amount, bytes32 srcTxId) external",
  "event TokenMinted(address indexed wrappedToken, address indexed to, uint256 amount, bytes32 indexed srcTxId)",
  "event WrappedBurned(address indexed wrappedToken, address indexed from, uint256 amount, bytes32 indexed burnId)",
  
  // Native coin functions and events
  "function mintNativeCoinWrapped(address to, uint256 amount, bytes32 srcTxId) external",
  "event NativeCoinWrappedMinted(address indexed to, uint256 amount, bytes32 indexed srcTxId)",
  "event NativeCoinWrappedBurned(address indexed from, uint256 amount, bytes32 indexed burnId)"
];

// Initialize wallet and connections
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY);

// Fuji C-Chain
const fujiProvider = new ethers.providers.JsonRpcProvider(process.env.FUJI_RPC);
const fujiSigner = wallet.connect(fujiProvider);
const locker = new ethers.Contract(FUJI_LOCKER_ADDRESS, LOCK_ABI, fujiSigner);

// Ulalo Network
const ulaloProvider = new ethers.providers.JsonRpcProvider(process.env.ULALO_RPC);
const ulaloSigner = wallet.connect(ulaloProvider);
const minter = new ethers.Contract(ULALO_MINTER_ADDRESS, MINTER_ABI, ulaloSigner);

console.log("🌉 Bridge Relayer Starting...");
console.log(`Connected to Fuji Locker: ${FUJI_LOCKER_ADDRESS}`);
console.log(`Connected to Ulalo Minter: ${ULALO_MINTER_ADDRESS}`);

// ERC20 Token Flow
// -------------------------------

// Listen for token lock events → Mint wrapped on Ulalo
locker.on("TokenLocked", async (token, sender, amount, txId, event) => {
  console.log(`🔐 Token Lock detected on Fuji: ${ethers.utils.formatEther(amount)} of ${token} from ${sender}`);
  console.log(`Transaction: ${event.transactionHash}`);
  
  try {
    const tx = await minter.mintWrapped(token, sender, amount, txId);
    console.log(`⏳ Minting on Ulalo (tx: ${tx.hash})...`);
    await tx.wait();
    console.log("✅ Wrapped tokens minted on Ulalo");
  } catch (err) {
    console.error("❌ Mint error:", err.reason || err);
  }
});

// Listen for token burns on Ulalo → Unlock on Fuji
minter.on("WrappedBurned", async (wrappedToken, from, amount, burnId, event) => {
  console.log(`🔥 Token Burn detected on Ulalo: ${ethers.utils.formatEther(amount)} of ${wrappedToken} by ${from}`);
  console.log(`Transaction: ${event.transactionHash}`);
  
  try {
    // Get the original token from the wrapped token - this might require a mapping function
    // This is a simplification - your actual implementation may need to look up the original token
    const originalToken = wrappedToken; // In real implementation, you'd map wrapped to original
    
    const tx = await locker.unlockToken(originalToken, from, amount);
    console.log(`⏳ Unlocking on Fuji (tx: ${tx.hash})...`);
    await tx.wait();
    console.log("✅ Tokens unlocked on Fuji");
  } catch (err) {
    console.error("❌ Unlock error:", err.reason || err);
  }
});

// Native Coin Flow
// -------------------------------

// Listen for native coin lock events → Mint wrapped on Ulalo
locker.on("NativeCoinLocked", async (sender, amount, txId, event) => {
  console.log(`🔐 Native Coin Lock detected on Fuji: ${ethers.utils.formatEther(amount)} AVAX from ${sender}`);
  console.log(`Transaction: ${event.transactionHash}`);
  
  try {
    const tx = await minter.mintNativeCoinWrapped(sender, amount, txId);
    console.log(`⏳ Minting wrapped native coin on Ulalo (tx: ${tx.hash})...`);
    await tx.wait();
    console.log("✅ Wrapped native coin minted on Ulalo");
  } catch (err) {
    console.error("❌ Native coin mint error:", err.reason || err);
  }
});

// Listen for native coin burns on Ulalo → Unlock on Fuji
minter.on("NativeCoinWrappedBurned", async (from, amount, burnId, event) => {
  console.log(`🔥 Native Coin Burn detected on Ulalo: ${ethers.utils.formatEther(amount)} wAVAX by ${from}`);
  console.log(`Transaction: ${event.transactionHash}`);
  
  try {
    const tx = await locker.unlockNativeCoin(from, amount);
    console.log(`⏳ Unlocking native coin on Fuji (tx: ${tx.hash})...`);
    await tx.wait();
    console.log("✅ Native coin unlocked on Fuji");
  } catch (err) {
    console.error("❌ Native coin unlock error:", err.reason || err);
  }
});

// Error handling and reconnection logic
fujiProvider.on("error", async (error) => {
  console.error("Fuji provider error:", error);
  await reconnectProvider(fujiProvider, process.env.FUJI_RPC);
});

ulaloProvider.on("error", async (error) => {
  console.error("Ulalo provider error:", error);
  await reconnectProvider(ulaloProvider, process.env.ULALO_RPC);
});

async function reconnectProvider(provider, rpcUrl) {
  console.log(`Attempting to reconnect to ${rpcUrl}...`);
  try {
    await provider.detectNetwork();
    console.log("Reconnection successful");
  } catch (error) {
    console.error("Reconnection failed:", error);
    // Implement exponential backoff retry logic here
  }
}

process.on("uncaughtException", (error) => {
  console.error("Uncaught exception:", error);
  // Consider implementing notification system here (e.g., email, Slack)
});

process.on("unhandledRejection", (reason, promise) => {
  console.error("Unhandled rejection at:", promise, "reason:", reason);
});

console.log("🚀 Relayer is running and listening for events...");
