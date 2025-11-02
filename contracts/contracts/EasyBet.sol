// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// Uncomment the line to use openzeppelin/ERC721,ERC20
// You can use this dependency directly because it has been installed by TA already
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Uncomment this line to use console.log
import "hardhat/console.sol";

contract EasyBet is ERC721,Ownable {

    // use a event if you want
    // to represent time you can choose block.timestamp
    //定义彩票购买事件
    event BetPlaced(uint256 tokenId, uint256 price, address owner);
    //定义创建活动事件
    event ActivityCreated(uint256 activityId, string name,uint256 start_time,uint256 end_time,uint256 total_pool);
    //定义挂单出售彩票事件
    event TicketListed(uint256 tokenId, uint256 price, address seller,uint256 activityId,uint256 choice);
    //定义取消挂单事件
    event TicketDelisted(uint256 tokenId, address seller);
    //定义彩票售出事件
    event TicketSold(uint256 tokenId, uint256 price, address buyer, address seller);
    //定义竞猜结算事件
    event ActivitySettled(uint256 activityId, uint256 win_choice);
    //定义奖金兑换事件
    event PrizeRedeemed(uint256 tokenId, address owner, uint256 amount);
    //定义订单簿匹配事件
    event OrderMatched(uint256 tokenId, uint256 price, address buyer, address seller, uint256 activityId, uint256 choice);
    //定义订单簿更新事件
    event OrderUpdated(uint256 activityId, uint256 order_count);


    // maybe you need a struct to store some activity information
    //活动结构变量
    struct Activity {
        address owner;
        // uint256 listedTimestamp;
        string[] choices;
        string name;
        uint256 start_time;
        uint256 end_time;
        uint256 total_pool;
        uint256 win_choice;
        bool is_settled;
        uint256 ticket_count;
        //记录每个选项的彩票数量
        mapping(uint256 => uint256) choice_ticket_count;
        Order[] orderbook;
    }
    //彩票结构变量
    struct Ticket {
        uint256 activityId;
        uint256 choice;
        uint256 buy_price;
        uint256 list_price;
        bool is_redeemed;
        //记录彩票在订单簿中的位置，便于删除
        uint256 order_index;
    }
    //订单结构变量
    struct Order {
        uint256 tokenId;
        uint256 price;
        address seller;
        uint256 activityId;
        uint256 choice;
        uint256 timestamp;
    }
    //订单簿价格档位结构变量
    struct Orderbook_Price_Level {
        uint256 price;
        uint256 count;
    }

    mapping(uint256 => Activity) public activities; // A map from activity-index to its information
    mapping(uint256 => Ticket) public tickets; // A map from tokenId to its information 
    mapping(address=>uint256) public user_balances; // A map from user address to its balance
    //下一个竞猜活动的ID
    uint256 public next_activityId = 1;
    //下一个彩票的ID
    uint256 public next_tokenId = 1;
    //竞猜使用的ERC20代币
    IERC20 public bet_token;

    constructor(address _bet_token_address) ERC721("EasyBetTicket", "EBT") Ownable(msg.sender) {
        bet_token = IERC20(_bet_token_address);
    }

    //向订单簿中插入订单
    function insert_order(uint256 activityId, Order memory new_order) internal returns (uint256){
        Activity storage activity = activities[activityId];
        Order[] storage orderbook = activity.orderbook;
        //当前订单簿为空，直接插入
        if(orderbook.length == 0){
            orderbook.push(new_order);
            //更新订单簿
            emit OrderUpdated(activityId, orderbook.length);
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
                tickets[orderbook[i].tokenId].order_index = i;
            }
            orderbook[low_index] = new_order;
            //更新订单簿
            emit OrderUpdated(activityId, orderbook.length);
            return low_index;
        }
    }

    //从订单簿删除订单
    function delete_order(uint256 activityId, uint256 order_index) internal {
        Activity storage activity = activities[activityId];
        Order[] storage orderbook = activity.orderbook;
        require(order_index < orderbook.length, "订单索引无效");
        for(uint256 i = order_index; i < orderbook.length - 1; i++){
            orderbook[i] = orderbook[i + 1];
            //更新彩票在订单簿中的索引
            tickets[orderbook[i].tokenId].order_index = i;
        }
        orderbook.pop();
        //更新订单簿
        emit OrderUpdated(activityId, orderbook.length);
    }

    //竞猜结算后清空订单簿
    function clear_orderbook(uint256 activityId) internal {
        Activity storage activity = activities[activityId];
        Order[] storage orderbook = activity.orderbook;
        for(uint256 i = 0; i < orderbook.length; i++){
            uint256 tokenId = orderbook[i].tokenId;
            Ticket storage ticket = tickets[tokenId];
            //更新彩票信息
            ticket.list_price = 0;
            ticket.order_index = 0;
            //触发取消挂单事件
            emit TicketDelisted(tokenId, orderbook[i].seller);
        }
        //删除订单簿
        delete activity.orderbook;
        //更新订单簿
        emit OrderUpdated(activityId, 0);
    }

    //执行彩票交易
    function trade_ticket(uint256 tokenId,address buyer) internal {
        Ticket storage ticket = tickets[tokenId];
        require(ticket.list_price > 0, "彩票未挂单");
        address seller = ownerOf(tokenId);
        uint256 price = ticket.list_price;
        uint256 activityId = ticket.activityId;
        uint256 order_index = ticket.order_index;
        //从订单簿删除订单
        delete_order(activityId, order_index);
        //更新订单信息
        ticket.list_price = 0;
        ticket.order_index = 0;
        ticket.buy_price = price;
        //代币转账支付
        require(bet_token.transferFrom(buyer, seller, price), "代币转账失败");
        //转移彩票所有权
        _transfer(seller, buyer, tokenId);
        //触发彩票售出事件
        emit TicketSold(tokenId, price, buyer, seller);
    }

    //公证人创建竞猜活动
    function create_activity(string memory name, string[] memory choices, uint256 start_time, uint256 end_time,uint256 total_pool) external onlyOwner {
        require(start_time < end_time, "开始时间必须早于结束时间");
        require(start_time > block.timestamp, "开始时间必须晚于当前时间");
        require(choices.length >= 2, "至少需要两个选项");
        require(total_pool > 0, "总奖池必须大于0");
        //分配竞猜活动标识符
        uint256 activityId = next_activityId;
        next_activityId++;
        Activity storage activity = activities[activityId];
        //初始化竞猜活动信息
        activity.owner = msg.sender;
        activity.choices = choices;
        activity.name = name;
        activity.start_time = start_time;
        activity.end_time = end_time;
        activity.total_pool = total_pool;
        //竞猜结果未知
        activity.win_choice = type(uint256).max;
        activity.is_settled = false;
        activity.ticket_count = 0;
        //初始化每个竞猜选项对应彩票数量映射表
        for(uint256 i = 0; i < choices.length; i++){
            activity.choice_ticket_count[i] = 0;
        }
        //初始奖池资金由创建者转账至合约账户
        require(bet_token.transferFrom(msg.sender, address(this), total_pool), "初始奖池代币转账失败");
        //触发创建活动事件
        emit ActivityCreated(activityId, name, start_time, end_time, total_pool);
    }

    //竞猜活动结算
    function settle_activity(uint256 activityId, uint256 win_choice) external onlyOwner {
        require(activities[activityId].owner == msg.sender, "只有活动创建者可以结算");
        require(activities[activityId].is_settled == false, "活动已结算");
        require(activityId>0&&activityId<next_activityId, "竞猜活动ID不存在");
        require(block.timestamp > activities[activityId].end_time, "活动未结束，无法结算");
        Activity storage activity = activities[activityId];
        require(win_choice < activity.choices.length, "获胜选项无效");
        //清空订单簿
        clear_orderbook(activityId);
        //更新竞猜活动信息
        activity.win_choice = win_choice;
        activity.is_settled = true;
        //触发竞猜结算事件
        emit ActivitySettled(activityId, win_choice);
    }

    //购买彩票
    function buy_ticket(uint256 activityId, uint256 choice, uint256 amount) external returns (uint256) {
        require(activityId>0&&activityId<next_activityId, "竞猜活动ID不存在");
        require(amount > 0, "购买彩票金额必须大于0");
        require(block.timestamp < activities[activityId].start_time, "活动未开始，无法购买彩票");
        require(block.timestamp >= activities[activityId].end_time, "活动已结束，无法购买彩票");
        Activity storage activity = activities[activityId];
        require(choice < activity.choices.length, "选择的选项无效");
        //分配彩票标识符
        uint256 tokenId=next_tokenId;
        next_tokenId++;
        Ticket storage ticket = tickets[tokenId];
        //初始化彩票信息
        ticket.activityId = activityId;
        ticket.choice = choice;
        ticket.buy_price = amount;
        ticket.list_price = 0;
        ticket.is_redeemed = false;
        ticket.order_index = 0;
        //更新竞猜活动信息
        activity.ticket_count++;
        activity.choice_ticket_count[choice]++;
        activity.total_pool += amount;
        //玩家向合约账户转账购买彩票所需代币
        require(bet_token.transferFrom(msg.sender, address(this), amount), "购买彩票代币转账失败");
        //触发购买彩票事件
        emit BetPlaced(tokenId, amount, msg.sender);
        return tokenId;
    }

    //挂单出售彩票
    function list_ticket(uint256 tokenId, uint256 price) external {
        require(ownerOf(tokenId) == msg.sender, "只有彩票所有者可以挂单出售");
        require(price > 0, "挂单价格必须大于0");
        Ticket storage ticket = tickets[tokenId];
        //如果彩票已经挂单了先取消原先的
        if(ticket.list_price > 0){
            uint256 activityId = ticket.activityId;
            //从订单簿删除订单
            delete_order(activityId, ticket.order_index);
            //触发取消挂单事件
            emit TicketDelisted(tokenId, msg.sender);
        }
        ticket.list_price = price;
        //创建新订单
        Order memory new_order = Order({
            tokenId: tokenId,
            price: price,
            seller: msg.sender,
            activityId: ticket.activityId,
            choice: ticket.choice,
            timestamp: block.timestamp
        });
        //将订单插入订单簿
        ticket.order_index = insert_order(ticket.activityId, new_order);
        //授权合约地址转移彩票
        _approve(address(this), tokenId);
        //触发挂单出售事件
        emit TicketListed(tokenId, price, msg.sender, ticket.activityId, ticket.choice);
    }

    //取消挂单
    function delist_ticket(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "只有彩票所有者可以取消挂单");
        Ticket storage ticket = tickets[tokenId];
        require(ticket.list_price > 0, "彩票未挂单");
        uint256 activityId = ticket.activityId;
        //从订单簿删除订单
        delete_order(activityId, ticket.order_index);
        //更新彩票信息
        ticket.list_price = 0;
        ticket.order_index = 0;
        //取消彩票转移授权
        _approve(address(0), tokenId);
        //触发取消挂单事件
        emit TicketDelisted(tokenId, msg.sender);
    }

    //购买挂单彩票
    function buy_ticket_listed(uint256 tokenId) external {
        Ticket storage ticket = tickets[tokenId];
        trade_ticket(tokenId, msg.sender);
    }

    //结算后兑换奖金
    function redeem_prize(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "只有彩票所有者可以兑换奖金");
        Ticket storage ticket = tickets[tokenId];
        require(ticket.is_redeemed == false, "奖金已兑换");
        Activity storage activity = activities[ticket.activityId];
        require(activity.is_settled == true, "活动未结算，无法兑换奖金");
        require(ticket.choice == activity.win_choice, "彩票未中奖，无法兑换奖金");
        require(activity.choice_ticket_count[activity.win_choice] > 0, "中奖选项无人购买彩票，无法兑换奖金");
        //计算奖金金额
        uint256 prize_amount = activity.total_pool / activity.choice_ticket_count[activity.win_choice] * ticket.buy_price;
        //更新彩票信息
        ticket.is_redeemed = true;
        //代币转账奖金
        user_balances[msg.sender] += prize_amount;
        //触发奖金兑换事件
        emit PrizeRedeemed(tokenId, msg.sender, prize_amount);
    }

    //提取余额
    function withdraw_balance() external {
        uint256 balance=user_balances[msg.sender];
        require(balance > 0, "余额为0，无可提取余额");
        user_balances[msg.sender] = 0;
        require(bet_token.transfer(msg.sender, balance), "余额提取失败");
    }

    //获取订单簿
    function get_orderbook(uint256 activityId) external view returns (Order[] memory) {
        require(activityId>0&&activityId<next_activityId, "竞猜活动ID不存在");
        Activity storage activity = activities[activityId];
        return activity.orderbook;
    }

    //获取订单簿价格档位分布
    function get_orderbook_price_level(uint256 activityId,uint256 choice) external view returns (Orderbook_Price_Level[] memory) {
        require(activityId>0&&activityId<next_activityId, "竞猜活动ID不存在");
        Activity storage activity = activities[activityId];
        Order[] storage orderbook = activity.orderbook;
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

    //获取竞猜活动信息
    function get_activity_info(uint256 activityId) external view returns (string memory name, string[] memory choices, uint256 start_time, uint256 end_time, uint256 total_pool, uint256 win_choice, bool is_settled, uint256 ticket_count) {
        require(activityId>0&&activityId<next_activityId, "竞猜活动ID不存在");
        Activity storage activity = activities[activityId];
        return (activity.name, activity.choices, activity.start_time, activity.end_time, activity.total_pool, activity.win_choice, activity.is_settled, activity.ticket_count);
    }

    //获取竞猜活动状态
    function get_activity_status(uint256 activityId) external view returns (string memory){
        require(activityId>0&&activityId<next_activityId, "竞猜活动ID不存在");
        Activity storage activity = activities[activityId];
        if(block.timestamp < activity.start_time){
            return "竞猜活动未开始";
        }
        else if(activity.is_settled==true){
            return "竞猜活动已结算";
        }
        else if(block.timestamp < activity.end_time){
            return "竞猜活动进行中";
        }
        else{
            return "竞猜活动已结束，待结算";
        }
    }

    //获取所有竞猜活动
    function get_all_activityId() external view returns (uint256[] memory) {
        uint256[] memory activityIds = new uint256[](next_activityId - 1);
        for(uint256 i = 1; i < next_activityId; i++){
            activityIds[i - 1] = i;
        }
        return activityIds;
    }

    //测试
    function helloworld() pure external returns(string memory) {
        return "hello world";
    }

    // ...
    // TODO add any logic if you want

    //重新定义_transfer函数
    function _transfer(address from, address to, uint256 tokenId) internal override {
        Ticket storage ticket = tickets[tokenId];
        //如果彩票还处于挂单状态，先取消挂单
        if(ticket.list_price > 0){
            //从订单簿删除订单
            delete_order(ticket.activityId, ticket.order_index);
            //更新彩票信息
            ticket.list_price = 0;
            ticket.order_index = 0;
            //触发取消挂单事件
            emit TicketDelisted(tokenId, from);
        }
        //调用父类_transfer函数完成转移
        super._transfer(from, to, tokenId);
    }
}
