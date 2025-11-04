# LAJ-blockchain-course-2025

## 项目介绍
> 进阶的去中心化彩票系统，参与方包括：竞猜玩家、公证人
>
> **背景**：传统的体育彩票系统（例如我国的体育彩票）一般没有彩票交易功能：例如，对于“NBA本赛季MVP为某球员/F1的赛季总冠军为某车队”这类持续时间长的事件的下注一般在赛季开始前就会买定离手，这使得一旦出现突发或不确定事件（如球员A赛季报销/球队B买入强力球星/C车队车手受伤等），很多玩家的选择便会立即失去意义，导致彩票游戏的可玩性下降。因此，一个有趣的探索方向是让彩票系统拥有合规、方便的交易功能。
>
> 建立一个进阶的去中心化彩票系统（可以是体育彩票，或其它任何比赛节目的竞猜，例如《中国好声音》《我是歌手》年度总冠军等，可以参考 [Polymarket](https://polymarket.com/) ），在网站中：
> - 公证人（你自己）可以创立许多竞猜项目：例如某场比赛的输赢、年度总冠军的得主等，每个项目应当有2个或多个可能的选项，一定的彩票总金额（由公证人提供），以及规定好的结果公布时间。
> - 玩家首先领取到测试所需以太币。在网站中，对于一个竞猜项目和多个可能的选项：
>   1. 每个竞彩玩家都可以选择其中的某个选项并购买一定金额（自己定义）的彩票，购买后该玩家会获得一张对应的彩票凭证（一个 ERC721 合约中的 Token）
>   2. 在竞彩结果公布之前，任何玩家之间可以买卖他们的彩票，以应对项目进行期间的任何突发状况。具体的买卖机制如下：一个玩家可以以指定的金额挂单出售（ERC721 Delegate）自己的彩票，其它玩家如果觉得该彩票有利可图就可以买入他的彩票。双方完成一次 ERC721 Token 交易。
>   3. 公证人可以在时间截止时（简单起见，你可以随时终止项目）输入竞猜的结果并进行结算。所有胜利的玩家可以平分奖池中的金额。
> - 额外地：
>   1. 发行一个 ERC20 合约，允许用户领取 ERC20 积分，并使用ERC20积分完成上述流程。
>   2. 对交易彩票的过程实现一个简单的链上订单簿：卖方用户可以以不同价格出售一种彩票，网页上显示当前订单簿的信息（多少价格有多少该彩票正在出售）。其他用户可以根据最优价格购买彩票。


## 如何运行

1. 在本地启动ganache应用。将端口改为8545，链id改为1337。相应地在MetaMask连接Ganache的url并导入需要的账户。

2. 在 `./contracts` 中安装需要的依赖，运行如下的命令：
    ```bash
    npm install
    ```
3. 在 `./contracts` 中编译合约，运行如下的命令：
    ```bash
    npx hardhat compile
    ```
4. 把`./contracts/hardhat.config.ts`中的url和账户私钥替换成Ganache中实际的。然后运行如下的命令：
    ```bash
    npx hardhat run .\scripts\deploy.ts --network ganache
    ```
5. 将命令行面板中输出的部署合约地址（我对`./contracts/scripts/deploy.ts`做了一定的修改）复制粘贴到相应前端组件`.tsx`文件中,例如在我运行时地址如下：
   ```bash
   const EASYBET_ADDRESS = "0x2B4b06a57a1feF879D5167065f0D6dbB3D8A86c2";
   const TOKEN_ADDRESS = "0x006d592C469AFBdCCa51E5e8FEd746942e7f8021";
   ```
6. 在 `./frontend` 中安装需要的依赖，运行如下的命令：
    ```bash
    npm install
    ```
7. 在 `./frontend` 中安装需要的依赖，运行如下的命令：
   ```bash
   npm install ethers@6
   ```
8. 在 `./frontend` 中启动前端程序，运行如下的命令：
    ```bash
    npm run start
    ```

## 功能实现分析

### 后端合约部分

#### 事件
```
event BetPlaced(uint256 tokenId, uint256 price, address owner);
event ActivityCreated(uint256 activityId, string name,uint256 start_time,uint256 end_time,uint256 total_pool);
event TicketListed(uint256 tokenId, uint256 price, address seller,uint256 activityId,uint256 choice);
event TicketDelisted(uint256 tokenId, address seller);
event TicketSold(uint256 tokenId, uint256 price, address buyer, address seller);
event ActivitySettled(uint256 activityId, uint256 win_choice);
event PrizeRedeemed(uint256 tokenId, address owner, uint256 amount);
event OrderUpdated(uint256 activityId, uint256 order_count);
```
- 定义彩票购买事件
- 定义创建活动事件
- 定义挂单出售彩票事件
- 定义取消挂单事件
- 定义彩票售出事件
- 定义竞猜结算事件
- 定义奖金兑换事件
- 定义订单簿更新事件

#### 主要结构变量

##### 活动结构变量
```
struct Activity {
    address owner;
    string[] choices;
    string name;
    uint256 start_time;
    uint256 end_time;
    uint256 total_pool;
    uint256 win_choice;
    bool is_settled;
    uint256 ticket_count;
    mapping(uint256 => uint256) choice_ticket_count;
    mapping(uint256 => uint256) choice_total_amount;
    OrderbookLib.Order[] orderbook;
}
```
- win_choice(uint256)：记录获胜选项，未结算前初始化为最大值
- is_settled(bool)：活动状态，是否结算
- choice_ticket_count(mapping(uint256 => uint256))：记录每个选项的彩票数量
- choice_total_amount(mapping(uint256 => uint256))：记录每个选项的彩票总数额
- orderbook(OrderbookLib.Order[])：该活动每个选项彩票的订单簿

##### 彩票结构变量
```
struct Ticket {
    uint256 activityId;
    uint256 choice;
    uint256 buy_price;
    uint256 list_price;
    bool is_redeemed;
    uint256 order_index;
}
```
- list_price(uint256)：记录挂单价格
- is_redeemed(bool)：记录是否已兑奖
- order_index(uint256)：记录彩票在订单簿中的位置索引，便于插入与删除操作

##### 订单记录结构变量
```
struct Order {
    uint256 tokenId;
    uint256 price;
    address seller;
    uint256 activityId;
    uint256 choice;
    uint256 timestamp;
}
```
- 变量本身命名即较容易理解不作赘述

##### 订单簿价格档位结构变量
```
struct Orderbook_Price_Level {
    uint256 price;
    uint256 count;
}
```
- 变量本身命名即较容易理解不作赘述

#### 映射表
```
mapping(uint256 => Activity) public activities
```
- 从activityId映射到对应活动
```
mapping(uint256 => Ticket) public tickets
```
- 从tokenId映射到对应彩票
```
mapping(address=>uint256) public user_balances
```
- 从用户地址映射到其账户余额
```
mapping(uint256=>uint256) internal ticket_order_index
```
- 从tokenId映射到该彩票在订单簿中的位置索引

#### 竞猜活动管理

##### 活动创建

```
function create_activity(string memory name, string[] memory choices, uint256 start_time, uint256 end_time,uint256 total_pool) external onlyOwner
```
- 使用动态数组string[] memory choices来支持任意数量的选项
- 给每一个活动分配一个标识符activityId，每分配一次自增一次
- 初始化活动基本信息，创建活动时获胜选项未知设为最大，结算状态也相应地设置为未结算
- 通过映射choice_ticket_count和choice_total_amount分别统计每个选项的参与情况
- 初始奖池资金由创建者转账至合约账户

##### 活动结算

```
function settle_activity(uint256 activityId, uint256 win_choice) external onlyOwner
```
- 结算时清空与该活动关联的订单簿
- 更新竞猜活动信息，包括传入获胜选项，以及把活动状态设为已结算
```
function clear_orderbook(Order[] storage orderbook,mapping(uint256=>uint256) storage ticket_order_index) internal
```
- 清空映射表原先记录的彩票在订单簿中的索引
- pop弹出所有订单簿中的订单记录以清空

##### 活动兑奖
```
function redeem_prize(uint256 tokenId) external
```
- 按比例分配最终奖金，prize_amount = activity.total_pool / activity.choice_ticket_count[activity.win_choice] * ticket.buy_price
- 更新彩票信息，使其变为已兑奖状态，不会二次兑奖
- 代币转账支付更新用户余额

##### 活动列表展示
```
function get_activity_info(uint256 activityId) external view returns (IEasyBet.ActivityInfo memory)
```

##### 活动状态获取
```
function get_activity_status(uint256 activityId) external view returns (string memory)
```

##### 获取所有活动
```
function get_all_activityId() external view returns (uint256[] memory)
```

#### 彩票及订单簿管理

##### 彩票购买

```
function buy_ticket(uint256 activityId, uint256 choice, uint256 amount) external returns (uint256)
```
- 给每一张彩票分配一个标识符tokenId，每分配一次自增一次
- 初始化彩票信息，传入相应参数值
- 更新竞猜活动信息，包括彩票总数、不同选项购买彩票数、总奖池等。
- 玩家向合约账户转账购买彩票所需代币，完成交易

##### 挂单出售彩票

```
function list_ticket(uint256 tokenId, uint256 price) external
```
- 如果彩票已经挂单了就先取消原先的，从订单簿删除挂单记录
- 然后创建新订单记录，把相应参数值传入并插入订单簿
- 授权合约地址转移彩票
```
function insert_order(Order[] storage orderbook, Order memory new_order,mapping(uint256=>uint256) storage ticket_order_index) internal returns (uint256)
```
- 如果当前订单簿为空则直接插入
- 否则使用二分查找的方式找到要插入的位置索引
- 移动该索引后的所有订单记录，后移一位，然后在该索引位置插入订单
  
##### 取消挂单彩票
```
function delist_ticket(uint256 tokenId) external
```
- 从订单簿删除订单记录
- 更新彩票信息，包括清空挂单价、订单簿索引信息
- 取消彩票转移授权并触发相应事件
```
function delete_order(Order[] storage orderbook, uint256 order_index,mapping(uint256=>uint256) storage ticket_order_index) internal
```
- 将要删除的订单记录后的订单记录全都前移一位，pop出最后一个多余的

##### 购买挂单的彩票
```
function buy_ticket_listed(uint256 tokenId) external
```
- 传入相应参数值后先从订单簿删除订单信息
- 然后更新订单信息使其变为未挂单状态
- 实现代币转账支付并转移彩票所有权

##### 订单簿价格统计
```
function get_orderbook_price_level(Order[] storage orderbook,uint256 choice) external view returns (Orderbook_Price_Level[] memory)
```
- 筛选只统计指定选项的订单
- 使用动态数组适应不同数量的价格档位
- 返回结构化的价格-数量对

##### 订单簿数据查询
```
function get_orderbook(uint256 activityId) external view returns (
    uint256[] memory tokenIds,
    uint256[] memory prices,
    address[] memory sellers,
    uint256[] memory activityIds,
    uint256[] memory choices,
    uint256[] memory timestamps
);
```

#### ERC20积分代币管理

定义每个用户可领取 1000 个完整代币，用hasClaimed映射记录每个地址的领取状态，防止重复领取。

##### 用户代币领取
```
function claimPoints() external
```
- !hasClaimed[msg.sender]确保每个地址只能领取一次
- 领取成功后立即设置 hasClaimed[msg.sender] = true
- 直接调用ERC20的_mint 函数，增加用户余额

##### 可控代币铸造
```
function mint(address to, uint256 amount) external onlyOwner
```
- 只有合约所有者可以调用可以向任意地址铸造任意数量的代币

##### 状态查询
```
function hasUserClaimed(address user) external view returns (bool)
```
- 任何人均可查询任意地址的领取状态，便于前端界面显示用户的领取状态


### 前端界面部分
#### `ActivityDetail.tsx`
##### 功能
- 展示活动的完整信息（选项、奖池、状态、获胜选项等）
  
##### 实现
- 用户可以选择某个选项并输入金额，调用buy_ticket购买彩票
- 在购票前执行ensureAllowance，保证合约能代扣代币

#### `ActivityList.tsx`
##### 功能
- 展示所有活动的基本信息（ID、名称、状态等）

#### `BuyByTokenId.tsx`
##### 功能
- 用户直接通过输入票券ID来购买挂单的彩票
  
##### 实现
- 在购买前调用ensureAllowance，保证合约有足够的代币授权
- 调用easyBet.buy_ticket_listed(tokenId)发起交易
- 购买成功后可调用onBuySuccess回调，刷新订单簿或票券列表

#### `CreateActivity.tsx`
##### 功能
- 用户输入活动名称、选项、开始/结束时间实现创建活动
  
##### 实现
- 用户输入活动信息，调用create_activity创建新活动
- 在调用前检查并执行approve，保证合约能收取创建活动所需的代币（如果有费用）

#### `MyTickets.tsx`
##### 功能
- 加载当前钱包地址下的所有票券（通过ownerOf遍历tokenId）
- 展示票券的活动 ID、选项、金额、兑奖状态
- 根据活动状态和中奖情况，显示不同的操作按钮

##### 实现
- 兑奖：调用redeem_prize，仅在活动已结算且票券为赢家时可用
- 挂单：输入价格后调用 list_ticket，并在前端自动执行approve（一次性无限额度），保证别人能买

#### `Orderbook.tsx`
##### 功能
- 加载指定活动的订单簿（get_orderbook）
- 展示所有挂单票券：票ID、价格、卖家、活动ID、选项、时间

##### 实现
- 买入：检查是否买自己的票（禁止自买）；调用ensureAllowance，如果额度不足则自动approve；调用buy_ticket_listed完成购买
- 下架：卖家可以调用delist_ticket下架自己的票

#### `TokenFaucet.tsx`
##### 功能
- 用户能够点击领取测试代币积分
- 每个用户地址只能领取一次

##### 实现
- 提供一个领取测试代币按钮
- 成功领取后按钮变灰，避免重复领取
- 通过onClaimSuccess回调联动钱包余额刷新

#### `Wallet.tsx`
##### 功能
- 展示钱包地址和余额，并提供刷新机制
- 与`TokenFaucet.tsx`联动，保证用户领取代币后能立刻看到余额变化

##### 实现
- 展示钱包信息：显示当前连接的钱包地址和用户持有的代币余额
- 实时刷新余额：提供一个loadBalance函数，调用ERC20合约的balanceOf(account)获取余额，在组件挂载时和onClaimSuccess回调时刷新余额
- 当用户在`TokenFaucet.tsx`领取代币成功后，触发onClaimSuccess，`Wallet.tsx`会自动刷新余额，用户能立即看到到账效果

## 项目运行截图
###  初始主界面
![初始主界面](./assets/image.png)

## 参考内容

- 课程的参考Demo见：[DEMOs](https://github.com/LBruyne/blockchain-course-demos)。

- 快速实现 ERC721 和 ERC20：[模版](https://wizard.openzeppelin.com/#erc20)。记得安装相关依赖 ``"@openzeppelin/contracts": "^5.0.0"``。

- 如何实现ETH和ERC20的兑换？ [参考讲解](https://www.wtf.academy/en/docs/solidity-103/DEX/)
