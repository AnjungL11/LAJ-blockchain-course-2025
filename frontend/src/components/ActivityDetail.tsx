import React, { useState } from "react";
import { ethers } from "ethers";

export default function ActivityDetail({ easyBet, token }: any) {
  const [buyActId, setBuyActId] = useState("");
  const [buyChoice, setBuyChoice] = useState("");
  const [buyAmount, setBuyAmount] = useState("10");
  const [settleActId, setSettleActId] = useState("");
  const [settleChoice, setSettleChoice] = useState("");

  const buyTicket = async () => {
    try {
      const amt = ethers.parseUnits(buyAmount, 18);
      await token.approve(await easyBet.getAddress(), amt);
      const tx = await easyBet.buy_ticket(Number(buyActId), Number(buyChoice), amt);
      await tx.wait();
      alert("购票成功");
    } catch (err: any) {
      alert("购票失败: " + err.message);
    }
  };

  const settle = async () => {
    try {
      const tx = await easyBet.settle_activity(Number(settleActId), Number(settleChoice));
      await tx.wait();
      alert("结算完成");
    } catch (err: any) {
      alert("结算失败: " + err.message);
    }
  };

  const withdraw = async () => {
    try {
      const tx = await easyBet.withdraw_balance();
      await tx.wait();
      alert("提现成功");
    } catch (err: any) {
      alert("提现失败: " + err.message);
    }
  };

  return (
    <div style={{ border: "1px solid #ccc", padding: 16, marginTop: 20 }}>
      <h3>购票 / 结算 / 提现</h3>
      <div>
        <h4>购票</h4>
        <input placeholder="活动ID" value={buyActId} onChange={(e) => setBuyActId(e.target.value)} />
        <input placeholder="选项索引" value={buyChoice} onChange={(e) => setBuyChoice(e.target.value)} />
        <input placeholder="投注金额 (EBP)" value={buyAmount} onChange={(e) => setBuyAmount(e.target.value)} />
        <button onClick={buyTicket}>购票</button>
      </div>
      <div>
        <h4>结算活动</h4>
        <input placeholder="活动ID" value={settleActId} onChange={(e) => setSettleActId(e.target.value)} />
        <input placeholder="获胜选项索引" value={settleChoice} onChange={(e) => setSettleChoice(e.target.value)} />
        <button onClick={settle}>结算</button>
      </div>
      <div>
        <h4>提现</h4>
        <button onClick={withdraw}>提现</button>
      </div>
    </div>
  );
}
