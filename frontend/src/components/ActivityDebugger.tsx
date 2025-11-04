import React, { useState } from "react";
import { ethers } from "ethers";

export default function ActivityDebugger({ easyBet }: any) {
  const [activityId, setActivityId] = useState("");
  const [info, setInfo] = useState<any>(null);

  const loadInfo = async () => {
    try {
      if (!activityId) return;
      const res = await easyBet.get_activity_info(Number(activityId));
      const [name, choices, start_time, end_time, total_pool, win_choice, is_settled, ticket_count, choice_amounts] = res;

      setInfo({
        id: Number(activityId),
        name,
        choices,
        start_time: Number(start_time),
        end_time: Number(end_time),
        total_pool: ethers.formatUnits(total_pool, 18),
        win_choice: Number(win_choice),
        is_settled,
        ticket_count: Number(ticket_count),
        choice_amounts: choice_amounts.map((c: bigint) => ethers.formatUnits(c, 18)),
      });
    } catch (err: any) {
      alert("读取失败: " + err.message);
    }
  };

  const getStatus = (a: any) => {
    const now = Math.floor(Date.now() / 1000);
    if (a.is_settled) return "已结算";
    if (now < a.start_time) return "未开始";
    if (now >= a.start_time && now <= a.end_time) return "进行中";
    if (now > a.end_time && !a.is_settled) return "已结束待结算";
    return "未知";
  };

  return (
    <div style={{ border: "1px solid #f90", padding: 16, marginTop: 20 }}>
      <h3>🛠 活动调试工具</h3>
      <input
        placeholder="输入活动ID"
        value={activityId}
        onChange={(e) => setActivityId(e.target.value)}
      />
      <button onClick={loadInfo}>查询</button>

      {info && (
        <div style={{ marginTop: 20 }}>
          <p><b>ID:</b> {info.id}</p>
          <p><b>名称:</b> {info.name}</p>
          <p><b>选项:</b> {Array.isArray(info.choices) ? info.choices.join(", ") : String(info.choices)}</p>
          <p><b>开始时间:</b> {new Date(info.start_time * 1000).toLocaleString()}</p>
          <p><b>结束时间:</b> {new Date(info.end_time * 1000).toLocaleString()}</p>
          <p><b>奖池:</b> {info.total_pool} EBP</p>
          <p><b>票数:</b> {info.ticket_count}</p>
          <p><b>各选项金额:</b> {info.choice_amounts.join(", ")} EBP</p>
          <p><b>获胜选项:</b> {info.win_choice}</p>
          <p><b>状态:</b> {getStatus(info)}</p>
        </div>
      )}
    </div>
  );
}
