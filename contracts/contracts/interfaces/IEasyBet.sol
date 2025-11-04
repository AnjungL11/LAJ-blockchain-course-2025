// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IEasyBet {
    // struct Order{
    //     uint256 tokenId;
    //     uint256 price;
    //     uint256 seller;
    //     uint256 activityId;
    //     uint256 choice;
    //     uint256 timestamp;
    // }

    // struct Orderbook_Price_Level {
    //     uint256 price;
    //     uint256 count;
    // }

    function get_orderbook(uint256 activityId) external view returns (
        uint256[] memory tokenIds,
        uint256[] memory prices,
        address[] memory sellers,
        uint256[] memory activityIds,
        uint256[] memory choices,
        uint256[] memory timestamps
    );
    
    function get_orderbook_price_level(uint256 activityId, uint256 choice) external view returns (
        uint256[] memory prices,
        uint256[] memory counts
    );

    struct ActivityInfo {
        // address owner;
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
        // mapping(uint256 => uint256) choice_ticket_count;
        // mapping(uint256 => uint256) choice_total_amount;
        // Order[] orderbook;
        uint256[] choice_amounts;
    }

    // function get_orderbook(uint256 activityId) external view returns (Order[] memory);
    // function get_orderbook_price_level(uint256 activityId,uint256 choice) external view returns (Orderbook_Price_Level[] memory);
    function get_activity_info(uint256 activityId) external view returns (string memory name, string[] memory choices, uint256 start_time, uint256 end_time, uint256 total_pool, uint256 win_choice, bool is_settled, uint256 ticket_count,uint256[] memory choice_amounts);
    function get_activity_status(uint256 activityId) external view returns (string memory);
    function get_all_activityId() external view returns (uint256[] memory);
    function helloworld() pure external returns(string memory);
}
