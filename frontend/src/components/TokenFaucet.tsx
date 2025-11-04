import React, { useEffect, useState } from "react";
import { ethers } from "ethers";
import TokenAbi from "../abis/MyERC20.json";

const TOKEN_ADDRESS = "0x006d592C469AFBdCCa51E5e8FEd746942e7f8021";

export default function TokenFaucet({ signer, account, onClaimSuccess }: any) {
  const [loading, setLoading] = useState(false);
  const [claimed, setClaimed] = useState(false);

  const checkClaimed = async () => {
    if (!signer || !account) return;
    try {
      const token = new ethers.Contract(TOKEN_ADDRESS, TokenAbi.abi, signer);
      const res = await token.hasUserClaimed(account);
      setClaimed(res);
    } catch (err) {
      console.error("检查领取状态失败:", err);
    }
  };

  useEffect(() => {
    checkClaimed();
  }, [signer, account]);

  const claim = async () => {
    try {
      setLoading(true);
      const token = new ethers.Contract(TOKEN_ADDRESS, TokenAbi.abi, signer);
      const tx = await token.claimPoints();
      await tx.wait();
      alert("领取成功，测试积分已到账！");
      setClaimed(true);
      if (onClaimSuccess) onClaimSuccess();
    } catch (err: any) {
      alert("领取失败: " + err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ border: "1px solid #ccc", padding: 16, marginTop: 20 }}>
      <h3>领取测试积分</h3>
      <p>每个地址只能领取一次 1000 EBP</p>
      <button
        onClick={claim}
        disabled={loading || !account || claimed}
        style={{
          backgroundColor: claimed ? "#ccc" : "#4CAF50",
          color: "#fff",
          padding: "8px 16px",
          border: "none",
          cursor: claimed ? "not-allowed" : "pointer",
        }}
      >
        {claimed ? "已领取" : loading ? "领取中..." : "领取测试积分"}
      </button>
    </div>
  );
}
