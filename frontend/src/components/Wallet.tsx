import React, { useEffect, useImperativeHandle, useState, forwardRef } from "react";
import { ethers } from "ethers";
import TokenAbi from "../abis/MyERC20.json";

const TOKEN_ADDRESS = "0x006d592C469AFBdCCa51E5e8FEd746942e7f8021";

type Props = {
  account?: string;
  connect: () => void;
  provider?: ethers.BrowserProvider;
};

const Wallet = forwardRef<{ refreshBalance: () => void }, Props>(
  ({ account, connect, provider }, ref) => {
    const [ethBalance, setEthBalance] = useState<string>("0");
    const [tokenBalance, setTokenBalance] = useState<string>("0");

    const refreshBalance = async () => {
      if (!provider || !account) return;
      try {
        // ETH 余额
        const bal = await provider.getBalance(account);
        setEthBalance(ethers.formatEther(bal));

        // Token 余额
        const signer = await provider.getSigner();
        const token = new ethers.Contract(TOKEN_ADDRESS, TokenAbi.abi, signer);
        const tbal = await token.balanceOf(account);
        setTokenBalance(ethers.formatUnits(tbal, 18));
      } catch (err) {
        console.error("刷新余额失败:", err);
      }
    };

    useImperativeHandle(ref, () => ({
      refreshBalance,
    }));

    useEffect(() => {
      if (account) refreshBalance();
    }, [account]);

    return (
      <div style={{ border: "1px solid #ccc", padding: 16 }}>
        <h3>钱包</h3>
        {account ? (
          <>
            <p>账户: {account}</p>
            <p>ETH 余额: {ethBalance}</p>
            <p>Token 余额: {tokenBalance}</p>
            <button onClick={refreshBalance}>刷新余额</button>
          </>
        ) : (
          <button onClick={connect}>连接钱包</button>
        )}
      </div>
    );
  }
);

export default Wallet;
