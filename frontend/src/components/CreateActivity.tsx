import React, { useState } from "react";
import { ethers } from "ethers";

export default function CreateActivity({ easyBet, token }: any) {
  const [name, setName] = useState("");
  const [choices, setChoices] = useState("胜,负");
  const [start, setStart] = useState("");
  const [end, setEnd] = useState("");
  const [pool, setPool] = useState("1000");

  const create = async () => {
    try {
      const poolWei = ethers.parseUnits(pool, 18);
      await token.approve(await easyBet.getAddress(), poolWei);
      const choiceArr = choices.split(",").map((s) => s.trim());
      const tx = await easyBet.create_activity(
        name,
        choiceArr,
        Math.floor(new Date(start).getTime() / 1000),
        Math.floor(new Date(end).getTime() / 1000),
        poolWei
      );
      await tx.wait();
      alert("活动创建成功");
    } catch (err: any) {
      alert("创建失败: " + err.message);
    }
  };

  return (
    <div style={{ border: "1px solid #ccc", padding: 16, marginBottom: 20 }}>
      <h3>🆕 创建活动</h3>
      <input placeholder="活动名称" value={name} onChange={(e) => setName(e.target.value)} />
      <input placeholder="选项（用逗号分隔）" value={choices} onChange={(e) => setChoices(e.target.value)} />
      <input type="datetime-local" value={start} onChange={(e) => setStart(e.target.value)} />
      <input type="datetime-local" value={end} onChange={(e) => setEnd(e.target.value)} />
      <input placeholder="奖池金额 (EBP)" value={pool} onChange={(e) => setPool(e.target.value)} />
      <button onClick={create}>创建活动</button>
    </div>
  );
}
