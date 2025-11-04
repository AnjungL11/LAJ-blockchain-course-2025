import React, { useEffect, useState, useMemo } from "react";
import { ethers } from "ethers";
import TokenAbi from "../abis/MyERC20.json";
import EasyBetAbi from "../abis/EasyBet.json";

const EASYBET_ADDRESS = "0x2B4b06a57a1feF879D5167065f0D6dbB3D8A86c2";
const TOKEN_ADDRESS = "0x006d592C469AFBdCCa51E5e8FEd746942e7f8021";

type OrderRow = {
  tokenId: number;
  price: string;
  priceWei: bigint;
  seller: string;
  activityId: number;
  choice: number;
  time: string;
};

export default function Orderbook({ signer, account }: any) {
  const [activityId, setActivityId] = useState("1");
  const [orders, setOrders] = useState<OrderRow[]>([]);
  const [loading, setLoading] = useState(false);

  const easyBet = useMemo(() => {
    return signer ? new ethers.Contract(EASYBET_ADDRESS, EasyBetAbi.abi, signer) : null;
  }, [signer]);

  const token = useMemo(() => {
    return signer ? new ethers.Contract(TOKEN_ADDRESS, TokenAbi.abi, signer) : null;
  }, [signer]);

  const loadOrders = async () => {
    if (!easyBet) return;
    try {
      // 按照合约返回值顺序解构
      const [tokenIds, prices, sellers, activityIds, choices, timestamps] =
        await easyBet.get_orderbook(ethers.toBigInt(activityId));

      const arr: OrderRow[] = tokenIds.map((id: bigint, i: number) => ({
        tokenId: Number(id),
        price: ethers.formatUnits(prices[i], 18),
        priceWei: prices[i],
        seller: sellers[i],
        activityId: Number(activityIds[i]),
        choice: Number(choices[i]),
        time: new Date(Number(timestamps[i]) * 1000).toLocaleString(),
      }));

      setOrders(arr);
    } catch (err: any) {
      console.error("加载订单簿失败:", err);
      alert("加载订单簿失败: " + (err?.message || String(err)));
    }
  };

  useEffect(() => {
    if (easyBet) loadOrders();
  }, [easyBet, activityId]);

  const ensureAllowance = async (spender: string, needed: bigint) => {
    if (!token || !account) return false;
    const current = await token.allowance(account, spender);
    if (current >= needed) return true;
    const tx = await token.approve(spender, needed);
    await tx.wait();
    const after = await token.allowance(account, spender);
    return after >= needed;
  };

  const buyRow = async (row: OrderRow) => {
    if (!easyBet || !token || !account) {
      alert("合约或账户未初始化");
      return;
    }
    try {
      setLoading(true);

      if (row.seller.toLowerCase() === account.toLowerCase()) {
        alert("不能购买自己的挂单");
        return;
      }

      const ok = await ensureAllowance(await easyBet.getAddress(), row.priceWei);
      if (!ok) {
        alert("授权失败或额度不足");
        return;
      }

      const tx = await easyBet.buy_ticket_listed(row.tokenId, {
        gasLimit: ethers.toBigInt(400000),
      });

      const receipt = await tx.wait();
      if (receipt.status === 1) {
        alert(`成功买入票券 #${row.tokenId}`);
        await loadOrders();
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

  const delistRow = async (row: OrderRow) => {
    if (!easyBet) return;
    try {
      const tx = await easyBet.delist_ticket(row.tokenId, {
        gasLimit: ethers.toBigInt(200000),
      });
      const receipt = await tx.wait();
      if (receipt.status === 1) {
        alert(`票券 #${row.tokenId} 已下架`);
        await loadOrders();
      } else {
        alert("下架失败，请检查链上状态");
      }
    } catch (err: any) {
      alert("下架失败: " + (err?.message || String(err)));
    }
  };

  return (
    <div style={{ border: "1px solid #ccc", padding: 16, marginTop: 20 }}>
      <h3>订单簿</h3>
      <div>
        <input
          placeholder="活动ID"
          value={activityId}
          onChange={(e) => setActivityId(e.target.value)}
        />
        <button onClick={loadOrders} disabled={loading}>刷新</button>
      </div>
      <table
        border={1}
        cellPadding={6}
        style={{ borderCollapse: "collapse", width: "100%", marginTop: 10 }}
      >
        <thead>
          <tr>
            <th>票ID</th>
            <th>价格</th>
            <th>卖家</th>
            <th>活动ID</th>
            <th>选项</th>
            <th>时间</th>
            <th>操作</th>
          </tr>
        </thead>
        <tbody>
          {orders.map((o) => (
            <tr key={o.tokenId}>
              <td>{o.tokenId}</td>
              <td>{o.price}</td>
              <td>{o.seller}</td>
              <td>{o.activityId}</td>
              <td>{o.choice}</td>
              <td>{o.time}</td>
              <td>
                <button onClick={() => buyRow(o)} disabled={loading}>买入</button>
                <button onClick={() => delistRow(o)} disabled={loading}>下架</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
