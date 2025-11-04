import React, { useEffect, useState } from "react";
import { ethers } from "ethers";

type Ticket = {
  tokenId: number;
  activityId: number;
  choice: number;
  buy_price: string;
  reward: string;
  is_redeemed: boolean;
};

type Activity = {
  name: string;
  win_choice: number;
  is_settled: boolean;
};

export default function MyTickets({ easyBet, account }: any) {
  const [tickets, setTickets] = useState<Ticket[]>([]);
  const [activities, setActivities] = useState<Record<number, Activity>>({});

  // 加载我的票券
  const loadTickets = async () => {
    if (!easyBet || !account) return;

    const arr: Ticket[] = [];
    const acts: Record<number, Activity> = {};

    for (let id = 1; id <= 200; id++) {
      try {
        const owner = await easyBet.ownerOf(id);
        if (owner.toLowerCase() !== account.toLowerCase()) continue;

        const t = await easyBet.tickets(id);
        const ticketObj: Ticket = {
          tokenId: id,
          activityId: Number(t[0]),
          choice: Number(t[1]),
          buy_price: ethers.formatUnits(t[2], 18),
          reward: t[3].toString(),
          is_redeemed: Boolean(t[4]),
        };
        arr.push(ticketObj);

        // 缓存活动的最关键字段
        const actId = ticketObj.activityId;
        if (!acts[actId]) {
          const a = await easyBet.activities(actId);
          acts[actId] = {
            name: a[1],
            win_choice: Number(a[5]),
            is_settled: Boolean(a[6]),
          };
        }
      } catch {
        // ownerOf(id) 失败说明不存在该token，跳过
      }
    }

    setTickets(arr);
    setActivities(acts);
  };

  useEffect(() => {
    loadTickets();
  }, [easyBet, account]);

  // 兑奖
  const claimRewardSafe = async (tokenId: number) => {
    try {
      const t = await easyBet.tickets(tokenId);
      const actId = Number(t[0]);
      const choice = Number(t[1]);
      const isRedeemed = Boolean(t[4]);
      const a = await easyBet.activities(actId);
      const winChoice = Number(a[5]);
      const isSettled = Boolean(a[6]);

      if (!isSettled) {
        alert("活动尚未结算，无法兑奖");
        return;
      }
      if (isRedeemed) {
        alert("该票已兑奖");
        return;
      }
      if (choice !== winChoice) {
        alert("未中奖，无法兑奖");
        return;
      }

      // 调用合约
      const tx = await easyBet.redeem_prize(tokenId);
      const receipt = await tx.wait();
      if (receipt.status === 1) {
        alert(`票券 #${tokenId} 兑奖成功`);
        await loadTickets();
      } else {
        alert("兑奖失败，请检查链上状态");
      }
    } catch (err: any) {
      alert("兑奖异常: " + (err?.message || String(err)));
    }
  };

  const listTicket = async (tokenId: number) => {
    try {
      const price = prompt("请输入挂单价格 (EBP)");
      if (!price) return;
      const priceWei = ethers.parseUnits(price, 18);
      const tx = await easyBet.list_ticket(tokenId, priceWei);
      await tx.wait();
      alert(`票券 #${tokenId} 挂单成功`);
    } catch (err: any) {
      alert("挂单失败: " + (err?.message || String(err)));
    }
  };

  return (
    <div style={{ border: "1px solid #ccc", padding: 16, marginTop: 20 }}>
      <h3>我的票券</h3>
      <button onClick={loadTickets}>刷新我的票券</button>

      <table
        border={1}
        cellPadding={6}
        style={{ borderCollapse: "collapse", width: "100%", marginTop: 10 }}
      >
        <thead>
          <tr>
            <th>票ID</th>
            <th>活动ID</th>
            <th>活动名称</th>
            <th>选项</th>
            <th>金额</th>
            <th>兑奖状态</th>
            <th>操作</th>
          </tr>
        </thead>
        <tbody>
          {tickets.map((t) => {
            const act = activities[t.activityId];
            const isSettled = act?.is_settled === true;
            const isWinner = isSettled && Number(t.choice) === Number(act?.win_choice);

            return (
              <tr key={t.tokenId}>
                <td>{t.tokenId}</td>
                <td>{t.activityId}</td>
                <td>{act ? act.name : "-"}</td>
                <td>{t.choice}</td>
                <td>{t.buy_price}</td>
                <td>
                  {t.is_redeemed
                    ? "已兑奖"
                    : isSettled
                    ? (isWinner ? "可兑奖" : "未中奖")
                    : "未结算"}
                </td>
                <td>
                  {!t.is_redeemed && (
                    <>
                      {/* 兑奖 */}
                      {isWinner && (
                        <button onClick={() => claimRewardSafe(t.tokenId)}>
                          兑奖
                        </button>
                      )}

                      {/* 挂单 */}
                      <button
                        style={{ marginLeft: 8 }}
                        onClick={() => listTicket(t.tokenId)}
                      >
                        挂单
                      </button>
                    </>
                  )}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
