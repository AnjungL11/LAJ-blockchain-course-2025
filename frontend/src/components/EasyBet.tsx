import React, { useEffect, useState, useRef } from "react";
import { ethers } from "ethers";
import Wallet from "./Wallet";
import CreateActivity from "./CreateActivity";
import ActivityList from "./ActivityList";
import ActivityDetail from "./ActivityDetail";
import MyTickets from "./MyTickets";
import Orderbook from "./Orderbook";
import TokenFaucet from "./TokenFaucet";
import BuyByTokenId from "./BuyByTokenId";
import EasyBetAbi from "../abis/EasyBet.json";
import TokenAbi from "../abis/MyERC20.json";

const EASYBET_ADDRESS = "0x2B4b06a57a1feF879D5167065f0D6dbB3D8A86c2";
const TOKEN_ADDRESS = "0x006d592C469AFBdCCa51E5e8FEd746942e7f8021";

export default function EasyBet() {
  const [provider, setProvider] = useState<ethers.BrowserProvider>();
  const [signer, setSigner] = useState<ethers.JsonRpcSigner>();
  const [account, setAccount] = useState<string>();
  const [easyBet, setEasyBet] = useState<ethers.Contract>();
  const [token, setToken] = useState<ethers.Contract>();

  const walletRef = useRef<{ refreshBalance: () => void } | null>(null);

  useEffect(() => {
    if ((window as any).ethereum) {
      const p = new ethers.BrowserProvider((window as any).ethereum);
      setProvider(p);
    }
  }, []);

  const connectWallet = async () => {
    if (!provider) return;
    const accs = await provider.send("eth_requestAccounts", []);
    setAccount(accs[0]);
    const s = await provider.getSigner();
    setSigner(s);

    // 用signer初始化合约，保证写操作可用
    setEasyBet(new ethers.Contract(EASYBET_ADDRESS, EasyBetAbi.abi, s));
    setToken(new ethers.Contract(TOKEN_ADDRESS, TokenAbi.abi, s));
  };

  return (
    <div style={{ padding: 20, fontFamily: "Arial, sans-serif" }}>
      <h1 style={{ textAlign: "center" }}>EasyBet 去中心化彩票系统</h1>

      <section style={{ marginBottom: 30 }}>
        <Wallet
          ref={walletRef}
          account={account}
          connect={connectWallet}
          provider={provider}
        />
      </section>

      {easyBet && account && (
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 20 }}>
          <div>
            <CreateActivity easyBet={easyBet} token={token} />
            <ActivityList easyBet={easyBet} />
            <ActivityDetail easyBet={easyBet} token={token} />
          </div>

          <div>
            <MyTickets easyBet={easyBet} account={account} />
            <Orderbook signer={signer} account={account} />
            <TokenFaucet
              signer={signer}
              account={account}
              onClaimSuccess={() => walletRef.current?.refreshBalance()}
            />
            <BuyByTokenId signer={signer} account={account} />
          </div>
        </div>
      )}
    </div>
  );
}
