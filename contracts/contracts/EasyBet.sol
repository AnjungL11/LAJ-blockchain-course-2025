// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// Uncomment the line to use openzeppelin/ERC721,ERC20
// You can use this dependency directly because it has been installed by TA already
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MyERC20.sol";
import "./interfaces/IEasyBet.sol";
import "./libraries/OrderbookLib.sol";

// Uncomment this line to use console.log
import "hardhat/console.sol";

contract EasyBet is ERC721,Ownable {

    using OrderbookLib for OrderbookLib.Order[];

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
    // //定义订单簿匹配事件
    // event OrderMatched(uint256 tokenId, uint256 price, address buyer, address seller, uint256 activityId, uint256 choice);
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
        mapping(uint256 => uint256) choice_total_amount;
        // Order[] orderbook;
        OrderbookLib.Order[] orderbook;
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
    mapping(uint256=>uint256) internal ticket_order_index; // A map from tokenId to its order index in the orderbook
    //下一个竞猜活动的ID
    uint256 public next_activityId = 1;
    //下一个彩票的ID
    uint256 public next_tokenId = 1;
    //竞猜使用的ERC20代币
    IERC20 public bet_token;

    constructor(address _bet_token_address) ERC721("EasyBetTicket", "EBT") Ownable(msg.sender) {
        bet_token = IERC20(_bet_token_address);
    }

    //公证人创建竞猜活动
    function create_activity(string memory name, string[] memory choices, uint256 start_time, uint256 end_time,uint256 total_pool) external onlyOwner {
        require(start_time < end_time, "The start time must be before the end time");
        // require(start_time > block.timestamp, "The start time must be in the future");
        require(choices.length >= 2, "The number of choices must be at least 2");
        require(total_pool > 0, "The total pool must be greater than 0");
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
            activity.choice_total_amount[i] = 0;
        }
        //初始奖池资金由创建者转账至合约账户
        require(bet_token.transferFrom(msg.sender, address(this), total_pool), "Activity pool token transfer failed");
        //触发创建活动事件
        emit ActivityCreated(activityId, name, start_time, end_time, total_pool);
    }

    //竞猜活动结算
    function settle_activity(uint256 activityId, uint256 win_choice) external onlyOwner {
        require(activities[activityId].owner == msg.sender, "Only the activity owner can settle the activity");
        require(activities[activityId].is_settled == false, "Activity has already been settled");
        require(activityId>0&&activityId<next_activityId, "Activity ID does not exist");
        require(block.timestamp > activities[activityId].end_time, "Activity has not ended yet");
        Activity storage activity = activities[activityId];
        require(win_choice < activity.choices.length, "Invalid winning choice");
        //清空订单簿
        activity.orderbook.clear_orderbook(ticket_order_index);
        //触发订单簿更新事件
        emit OrderUpdated(activityId, 0);
        //更新竞猜活动信息
        activity.win_choice = win_choice;
        activity.is_settled = true;
        //触发竞猜结算事件
        emit ActivitySettled(activityId, win_choice);
    }

    //购买彩票
    function buy_ticket(uint256 activityId, uint256 choice, uint256 amount) external returns (uint256) {
        require(activityId>0&&activityId<next_activityId, "Activity ID does not exist");
        require(amount > 0, "The amount must be greater than 0");
        require(block.timestamp >= activities[activityId].start_time, "Activity has not started yet");
        require(block.timestamp < activities[activityId].end_time, "Activity has already ended");
        Activity storage activity = activities[activityId];
        require(choice < activity.choices.length, "Invalid choice");
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
        activity.choice_total_amount[choice] += amount;
        activity.total_pool += amount;
        //玩家向合约账户转账购买彩票所需代币
        require(bet_token.transferFrom(msg.sender, address(this), amount), "Ticket purchase token transfer failed");
        _safeMint(msg.sender, tokenId);
        //触发购买彩票事件
        emit BetPlaced(tokenId, amount, msg.sender);
        return tokenId;
    }

    //挂单出售彩票
    function list_ticket(uint256 tokenId, uint256 price) external {
        require(ownerOf(tokenId) == msg.sender, "Only the ticket owner can list the ticket for sale");
        require(price > 0, "The listing price must be greater than 0");
        Ticket storage ticket = tickets[tokenId];
        Activity storage activity = activities[ticket.activityId];
        //如果彩票已经挂单了先取消原先的
        if(ticket.list_price > 0){
            //从订单簿删除订单
            activity.orderbook.delete_order(ticket.order_index,ticket_order_index);
            //触发取消挂单事件
            emit TicketDelisted(tokenId, msg.sender);
        }
        ticket.list_price = price;
        //创建新订单
        OrderbookLib.Order memory new_order=OrderbookLib.Order({
            tokenId: tokenId,
            price: price,
            seller: msg.sender,
            activityId: ticket.activityId,
            choice: ticket.choice,
            timestamp: block.timestamp
        });
        //将订单插入订单簿
        ticket.order_index = activity.orderbook.insert_order(new_order,ticket_order_index);
        //授权合约地址转移彩票
        approve(address(this), tokenId);
        //触发挂单出售事件
        emit TicketListed(tokenId, price, msg.sender, ticket.activityId, ticket.choice);
        //触发订单簿更新事件
        emit OrderUpdated(ticket.activityId, activities[ticket.activityId].orderbook.length);
    }

    //取消挂单
    function delist_ticket(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Only the ticket owner can delist the ticket");
        Ticket storage ticket = tickets[tokenId];
        require(ticket.list_price > 0, "Ticket is not listed for sale");
        uint256 activityId = ticket.activityId;
        Activity storage activity = activities[activityId];
        //从订单簿删除订单
        activity.orderbook.delete_order(ticket.order_index,ticket_order_index);
        //更新彩票信息
        ticket.list_price = 0;
        ticket.order_index = 0;
        //取消彩票转移授权
        approve(address(0), tokenId);
        //触发取消挂单事件
        emit TicketDelisted(tokenId, msg.sender);
        //触发订单簿更新事件
        emit OrderUpdated(activityId, activities[activityId].orderbook.length);
    }

    //购买挂单彩票
    function buy_ticket_listed(uint256 tokenId) external {
        Ticket storage ticket = tickets[tokenId];
        require(ticket.list_price > 0, "Tickets is not listed for sale");
        address seller = ownerOf(tokenId);
        uint256 price = ticket.list_price;
        uint256 activityId = ticket.activityId;
        uint256 order_index = ticket.order_index;
        //从订单簿删除订单
        activities[activityId].orderbook.delete_order(order_index,ticket_order_index);
        //更新订单信息
        ticket.list_price = 0;
        ticket.order_index = 0;
        ticket.buy_price = price;
        //代币转账支付
        require(bet_token.transferFrom(msg.sender,seller,price), "Ticket purchase token transfer failed");
        // cancel_listing(tokenId,seller);
        //转移彩票所有权
        super.transferFrom(seller, msg.sender, tokenId);
        //触发彩票售出事件
        emit TicketSold(tokenId, price, msg.sender, seller);
        //触发订单簿更新事件
        emit OrderUpdated(activityId, activities[activityId].orderbook.length);
    }

    //结算后兑换奖金
    function redeem_prize(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Only the ticket owner can redeem the prize");
        Ticket storage ticket = tickets[tokenId];
        require(ticket.is_redeemed == false, "Ticket prize has already been redeemed");
        Activity storage activity = activities[ticket.activityId];
        require(activity.is_settled == true, "Activity has not been settled yet");
        require(ticket.choice == activity.win_choice, "Ticket choice is not the winning choice");
        require(activity.choice_ticket_count[activity.win_choice] > 0, "No tickets were purchased for the winning choice");
        require(activity.choice_total_amount[activity.win_choice] > 0, "No amount was bet on the winning choice");
        //计算奖金金额
        uint256 prize_amount = activity.total_pool / activity.choice_ticket_count[activity.win_choice] * ticket.buy_price;
        //更新彩票信息
        ticket.is_redeemed = true;
        //代币转账奖金
        user_balances[msg.sender] += prize_amount;
        // bet_token.safeTransfer(msg.sender, prize_amount);
        //触发奖金兑换事件
        emit PrizeRedeemed(tokenId, msg.sender, prize_amount);
    }

    //提取余额
    function withdraw_balance() external {
        uint256 balance=user_balances[msg.sender];
        require(balance > 0, "No balance to withdraw");
        user_balances[msg.sender] = 0;
        require(bet_token.transfer(msg.sender, balance), "Token withdrawal failed");
    }

    //获取订单簿
    function get_orderbook(uint256 activityId) external view returns (
        uint256[] memory tokenIds,
        uint256[] memory prices,
        address[] memory sellers,
        uint256[] memory activityIds,
        uint256[] memory choices,
        uint256[] memory timestamps
    ) {
        require(activityId>0&&activityId<next_activityId, "Activity ID does not exist");
        OrderbookLib.Order[] storage orderbook = activities[activityId].orderbook;
        // Order[] memory result = new Order[](orderbook.length);
        uint256 length = orderbook.length;
        tokenIds = new uint256[](length);
        prices = new uint256[](length);
        sellers = new address[](length);
        activityIds = new uint256[](length);
        choices = new uint256[](length);
        timestamps = new uint256[](length);
        for(uint256 i = 0; i < length; i++){
            tokenIds[i] = orderbook[i].tokenId;
            prices[i] = orderbook[i].price;
            sellers[i] = orderbook[i].seller;
            activityIds[i] = orderbook[i].activityId;
            choices[i] = orderbook[i].choice;
            timestamps[i] = orderbook[i].timestamp;
        }
        // return result;
    }

    // 获取订单簿价格档位分布
    function get_orderbook_price_level(uint256 activityId, uint256 choice) external view returns (
        uint256[] memory prices,
        uint256[] memory counts
    ) {
        require(activityId>0&&activityId<next_activityId, "Activity ID does not exist");
        OrderbookLib.Order[] storage orderbook = activities[activityId].orderbook;
        OrderbookLib.Orderbook_Price_Level[] memory price_level = orderbook.get_orderbook_price_level(choice);
        // Orderbook_Price_Level[] memory result = new Orderbook_Price_Level[](price_level.length);
        uint256 length = price_level.length;
        prices = new uint256[](length);
        counts = new uint256[](length);
        for(uint256 i = 0; i < length; i++){
            prices[i] = price_level[i].price;
            counts[i] = price_level[i].count;
        }
        // return result;
    }

    //获取竞猜活动信息
    function get_activity_info(uint256 activityId) external view returns (IEasyBet.ActivityInfo memory) {
        require(activityId>0&&activityId<next_activityId, "Activity ID does not exist");
        Activity storage activity = activities[activityId];
        uint256[] memory amounts = new uint256[](activity.choices.length);
        for(uint256 i = 0; i < activity.choices.length; i++){
            amounts[i] = activity.choice_total_amount[i];
        }
        IEasyBet.ActivityInfo memory activity_info;
        activity_info.name = activity.name;
        activity_info.choices = activity.choices;
        activity_info.start_time =  activity.start_time;
        activity_info.end_time = activity.end_time;
        activity_info.total_pool = activity.total_pool;
        activity_info.win_choice = activity.win_choice;
        activity_info.is_settled = activity.is_settled;
        activity_info.ticket_count = activity.ticket_count;
        activity_info.choice_amounts = amounts;
        return activity_info;
    }

    //获取竞猜活动状态
    function get_activity_status(uint256 activityId) external view returns (string memory){
        require(activityId>0&&activityId<next_activityId, "Activity ID does not exist");
        Activity storage activity = activities[activityId];
        if(block.timestamp < activity.start_time){
            return "Activity not started";
        }
        else if(activity.is_settled==true){
            return "Activity settled";
        }
        else if(block.timestamp < activity.end_time){
            return "Activity ongoing";
        }
        else{
            return "Activity ended, waiting for settlement";
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
}
