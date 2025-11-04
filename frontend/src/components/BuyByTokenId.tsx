import React, { useState, useMemo } from "react";
import { ethers } from "ethers";
import EasyBetAbi from "../abis/EasyBet.json";
import TokenAbi from "../abis/MyERC20.json";

const EASYBET_ADDRESS = "0x2B4b06a57a1feF879D5167065f0D6dbB3D8A86c2";
const TOKEN_ADDRESS = "0x006d592C469AFBdCCa51E5e8FEd746942e7f8021";

export default function BuyByTokenId({ signer, account }: any) {
  const [tokenId, setTokenId] = useState("");
  const [loading, setLoading] = useState(false);

  const easyBet = useMemo(() => {
    return signer ? new ethers.Contract(EASYBET_ADDRESS, EasyBetAbi.abi, signer) : null;
  }, [signer]);

  const token = useMemo(() => {
    return signer ? new ethers.Contract(TOKEN_ADDRESS, TokenAbi.abi, signer) : null;
  }, [signer]);

  const ensureAllowance = async (spender: string, needed: bigint) => {
    if (!token || !account) return false;
    const current: bigint = await token.allowance(account, spender);
    if (current >= needed) return true;
    const tx = await token.approve(spender, needed);
    await tx.wait();
    const after: bigint = await token.allowance(account, spender);
    return after >= needed;
  };

  const buyTicket = async () => {
    if (!easyBet || !account) {
      alert("合约或账户未初始化");
      return;
    }
    try {
      setLoading(true);

      // 读取票信息
      const ticket = await easyBet.tickets(ethers.toBigInt(tokenId));
      const price: bigint = ticket.list_price as bigint;

      if (!price || price === BigInt(0)) {
        alert("该票未挂单或价格为0");
        return;
      }

      // 确认授权
      const ok = await ensureAllowance(await easyBet.getAddress(), price);
      if (!ok) {
        alert("授权失败或额度不足");
        return;
      }

      // 调用买入
      const tx = await easyBet.buy_ticket_listed(ethers.toBigInt(tokenId), {
        gasLimit: ethers.toBigInt(400000),
      });
      const receipt = await tx.wait();

      if (receipt.status === 1) {
        alert(`成功买入票券 #${tokenId}`);
      } else {
        alert("交易失败，请检查链上状态");
      }
    } catch (err: any) {
      console.error("买入异常:", err);
      alert("买入异常: " + (err?.message || String(err)));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ border: "1px solid #ccc", padding: 16, marginTop: 20 }}>
      <h3>按票ID买入</h3>
      <input
        placeholder="输入票ID"
        value={tokenId}
        onChange={(e) => setTokenId(e.target.value)}
      />
      <button onClick={buyTicket} disabled={loading || !tokenId}>
        {loading ? "买入中..." : "买入"}
      </button>
    </div>
  );
}
