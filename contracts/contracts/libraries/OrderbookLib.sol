// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

library OrderbookLib {
    struct Order {
        uint256 tokenId;
        uint256 price;
        address seller;
        uint256 activityId;
        uint256 choice;
        uint256 timestamp;
    }

    struct Orderbook_Price_Level {
        uint256 price;
        uint256 count;
    }

    //向订单簿中插入订单
    function insert_order(Order[] storage orderbook, Order memory new_order,mapping(uint256=>uint256) storage ticket_order_index) internal returns (uint256){
        //当前订单簿为空，直接插入
        if(orderbook.length == 0){
            orderbook.push(new_order);
            return 0;
        }
        else{
            uint256 low_index = 0;
            uint256 high_index = orderbook.length;
            //二分查找插入位置
            while(low_index < high_index){
                uint256 mid_index = (low_index + high_index) / 2;
                if(orderbook[mid_index].price < new_order.price){
                    low_index = mid_index + 1;
                }else{
                    high_index = mid_index;
                }
            }
            orderbook.push();
            for(uint256 i = orderbook.length - 1; i > low_index; i--){
                orderbook[i] = orderbook[i - 1];
                //更新彩票在订单簿中的索引
                ticket_order_index[orderbook[i].tokenId]= i;
            }
            orderbook[low_index] = new_order;
            ticket_order_index[new_order.tokenId]= low_index;
            return low_index;
        }
    }

    //从订单簿删除订单
    function delete_order(Order[] storage orderbook, uint256 order_index,mapping(uint256=>uint256) storage ticket_order_index) internal {
        require(order_index < orderbook.length, "Invalid order index");
        ticket_order_index[orderbook[order_index].tokenId] = 0;
        for(uint256 i = order_index; i < orderbook.length - 1; i++){
            orderbook[i] = orderbook[i + 1];
            //更新彩票在订单簿中的索引
            ticket_order_index[orderbook[i].tokenId] = i;
        }
        orderbook.pop();
    }

    //竞猜结算后清空订单簿
    function clear_orderbook(Order[] storage orderbook,mapping(uint256=>uint256) storage ticket_order_index) internal {
        for(uint256 i = 0; i < orderbook.length; i++){
            ticket_order_index[orderbook[i].tokenId] = 0;
        }
        // //删除订单簿
        // delete orderbook;
        while(orderbook.length>0){
            orderbook.pop();
        }
    }

    // 获取订单簿价格档位分布
    function get_orderbook_price_level(Order[] storage orderbook,uint256 choice) external view returns (Orderbook_Price_Level[] memory) {
        uint256[] memory unique_prices = new uint256[](orderbook.length);
        uint256[] memory price_counts = new uint256[](orderbook.length);
        uint256 unique_count = 0;
        //统计不同价格档位及其对应订单数量
        for(uint256 i = 0; i < orderbook.length; i++){
            if(orderbook[i].choice == choice){
                bool flag = false;
                for(uint256 j = 0; j < unique_count; j++){
                    if(orderbook[i].price == unique_prices[j]){
                        price_counts[j]++;
                        flag = true;
                        break;
                    }
                }
                //如果这个价格之前没有读到过
                if(flag==false){
                    unique_prices[unique_count] = orderbook[i].price;
                    price_counts[unique_count] = 1;
                    unique_count++;
                }
            }
        }
        //构建返回结果
        Orderbook_Price_Level[] memory price_level = new Orderbook_Price_Level[](unique_count);
        for(uint256 i = 0; i < unique_count; i++){
            price_level[i]=Orderbook_Price_Level({
                price: unique_prices[i],
                count: price_counts[i]
            });
        }
        return price_level;
    }
}
