<div align="center">

# 🚀 CryptoHub Ghana

**A decentralized crypto price tracker built for Ghana, powered by blockchain.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![React](https://img.shields.io/badge/React-18-61DAFB?logo=react&logoColor=white)](https://reactjs.org/)
[![TailwindCSS](https://img.shields.io/badge/Tailwind_CSS-3.x-38B2AC?logo=tailwind-css&logoColor=white)](https://tailwindcss.com/)
[![Solidity](https://img.shields.io/badge/Solidity-0.8-363636?logo=solidity&logoColor=white)](https://soliditylang.org/)
[![Ethereum](https://img.shields.io/badge/Network-Testnet-3C3C3D?logo=ethereum&logoColor=white)](https://ethereum.org/)
[![Web3.js](https://img.shields.io/badge/Web3.js-1.x-F16822?logo=web3dotjs&logoColor=white)](https://web3js.readthedocs.io/)
[![CoinGecko](https://img.shields.io/badge/API-CoinGecko-8DC63F?logo=coingecko&logoColor=white)](https://www.coingecko.com/en/api)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Made in Ghana](https://img.shields.io/badge/Made%20in-Ghana%20🇬🇭-006B3F)](https://github.com/KelvCodes/CryptoHubGhana)

Real-time crypto prices. On-chain interaction logging. Wallet-connected.  
Built for enthusiasts, traders, and auditors across Ghana and beyond.

[Getting Started](#-getting-started) · [Features](#-features) · [Tech Stack](#-tech-stack) · [Contributing](#-contributing)

</div>

---

## ✨ Features

- 📈 **Live Price Tracking** — Real-time cryptocurrency data powered by the CoinGecko API
- 🔗 **On-Chain Logging** — User interactions recorded transparently via a Solidity smart contract on Ethereum testnet
- 🦊 **Wallet Integration** — Seamlessly connect MetaMask or any Web3-compatible wallet
- 🎨 **Sleek UI** — Responsive, modern interface built with React and Tailwind CSS
- 🌍 **Ghana-First** — Designed with the local crypto community in mind

---

## 🛠️ Tech Stack

| Layer | Technology | Badge |
|---|---|---|
| Smart Contracts | Solidity (Ethereum Testnet) | ![Solidity](https://img.shields.io/badge/Solidity-363636?logo=solidity&logoColor=white) |
| Frontend | React | ![React](https://img.shields.io/badge/React-61DAFB?logo=react&logoColor=black) |
| Styling | Tailwind CSS | ![Tailwind](https://img.shields.io/badge/Tailwind_CSS-38B2AC?logo=tailwind-css&logoColor=white) |
| Blockchain Bridge | Web3.js | ![Web3](https://img.shields.io/badge/Web3.js-F16822?logo=web3dotjs&logoColor=white) |
| Price Data | CoinGecko API | ![CoinGecko](https://img.shields.io/badge/CoinGecko-8DC63F?logo=coingecko&logoColor=white) |
| Package Manager | npm | ![npm](https://img.shields.io/badge/npm-CB3837?logo=npm&logoColor=white) |

---

## ⚡ Getting Started

### Prerequisites

![Node](https://img.shields.io/badge/Node.js-≥16-339933?logo=nodedotjs&logoColor=white)
![MetaMask](https://img.shields.io/badge/MetaMask-Required-E2761B?logo=metamask&logoColor=white)

- **Node.js** ≥ 16
- **MetaMask** browser extension (or any Web3 wallet)
- A free [CoinGecko API key](https://www.coingecko.com/en/api) *(optional for higher rate limits)*

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/KelvCodes/CryptoHubGhana.git
cd CryptoHubGhana

# 2. Install dependencies
npm install

# 3. Configure environment variables
cp .env.example .env
# Add your CoinGecko API key and testnet RPC URL to .env

# 4. Start the app
npm start
```

Open [http://localhost:3000](http://localhost:3000), connect your wallet, and start tracking. 🎉

---

## 🔄 How It Works

```
Connect Wallet  →  Fetch Live Prices  →  Interact with dApp  →  Log to Blockchain
     🦊                  📈                      🖱️                     🔗
```

1. 🦊 **Connect** your MetaMask wallet to the Ethereum testnet
2. 📈 **Browse** live crypto prices pulled from CoinGecko in real time
3. 🖱️ **Interact** — search, filter, and explore your favourite coins
4. 🔗 **Log** — each interaction is optionally recorded on-chain for full transparency
5. 📜 **Audit** — anyone can verify the interaction history on the testnet explorer

---

## 📁 Project Structure

```
CryptoHubGhana/
├── 📂 contracts/          # Solidity smart contracts (interaction logger)
├── 📂 migrations/         # Truffle deployment scripts
├── 📂 src/
│   ├── 📂 components/     # React UI components
│   ├── 📂 hooks/          # Custom React hooks (price fetching, Web3)
│   ├── 📂 utils/          # API helpers and Web3 utilities
│   └── 📄 App.js
├── 📂 test/               # Contract tests
├── 📄 .env.example        # Environment variable template
└── 📄 truffle-config.js
```

---

## 🌐 Environment Variables

Create a `.env` file in the root directory:

```env
REACT_APP_COINGECKO_API_KEY=your_api_key_here
REACT_APP_RPC_URL=https://your-testnet-rpc-url
REACT_APP_CONTRACT_ADDRESS=0xYourDeployedContractAddress
```

---

## 🤝 Contributing

[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![GitHub issues](https://img.shields.io/github/issues/KelvCodes/CryptoHubGhana)](https://github.com/KelvCodes/CryptoHubGhana/issues)
[![GitHub forks](https://img.shields.io/github/forks/KelvCodes/CryptoHubGhana)](https://github.com/KelvCodes/CryptoHubGhana/network)
[![GitHub stars](https://img.shields.io/github/stars/KelvCodes/CryptoHubGhana)](https://github.com/KelvCodes/CryptoHubGhana/stargazers)

All contributions are welcome — whether it's a bug fix, new feature, or docs improvement.

1. 🍴 Fork the repository
2. 🌿 Create a feature branch: `git checkout -b feature/your-feature`
3. 💾 Commit your changes: `git commit -m "Add your feature"`
4. 🚀 Push and open a Pull Request

Please open an issue first to discuss major changes.

---

## 📄 License

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

[MIT](LICENSE) — free to use, modify, and distribute.

---

<div align="center">

*Built with 🖤 to bring crypto transparency to Ghana and the world.*

[![GitHub](https://img.shields.io/badge/GitHub-KelvCodes-181717?logo=github&logoColor=white)](https://github.com/KelvCodes)

</div>
