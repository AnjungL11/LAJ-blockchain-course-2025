import React, { useEffect, useState } from "react";
import { ethers } from "ethers";

export default function ActivityList({ easyBet }: any) {
  const [activities, setActivities] = useState<any[]>([]);

  const load = async () => {
    const ids: bigint[] = await easyBet.get_all_activityId();
    const infos: any[] = [];
    for (let id of ids) {
      const res = await easyBet.get_activity_info(id);
      const [name, choices, start_time, end_time, total_pool, win_choice, is_settled] = res;
      infos.push({ id: Number(id), name, choices, start_time, end_time, total_pool, win_choice, is_settled });
    }
    setActivities(infos);
  };

  useEffect(() => { load(); }, [easyBet]);

  const getStatus = (a: any) => {
    const now = Math.floor(Date.now() / 1000);
    if (a.is_settled) return "已结算";
    if (now < Number(a.start_time)) return "未开始";
    if (now >= Number(a.start_time) && now <= Number(a.end_time)) return "进行中";
    if (now > Number(a.end_time) && !a.is_settled) return "已结束待结算";
    return "未知";
  };

  return (
    <div>
      <h3>活动列表</h3>
      <table border={1} cellPadding={6} style={{ borderCollapse: "collapse", width: "100%" }}>
        <thead>
          <tr>
            <th>ID</th><th>名称</th><th>选项</th><th>开始</th><th>结束</th><th>奖池</th><th>状态</th>
          </tr>
        </thead>
        <tbody>
          {activities.map((a) => (
            <tr key={a.id}>
              <td>{a.id}</td>
              <td>{a.name}</td>
              <td>{Array.isArray(a.choices) ? a.choices.join(", ") : String(a.choices)}</td>
              <td>{new Date(Number(a.start_time) * 1000).toLocaleString()}</td>
              <td>{new Date(Number(a.end_time) * 1000).toLocaleString()}</td>
              <td>{ethers.formatUnits(a.total_pool, 18)} EBP</td>
              <td>{getStatus(a)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
