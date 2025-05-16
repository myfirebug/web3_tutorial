// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
// https://docs.chain.link/data-feeds/getting-started
// import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  function getRoundData(
    uint80 _roundId
  ) external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

contract FundMe {
    // 1.创建一个收款函数
    // 2.记录投资人并且查看
    // 3.达到目标值，生产商可以提款
    // 4.在锁定期内，没有达到目标值，投资人可以退款 
    // docs.chain.link
    mapping (address => uint256) public funderToAmount;

    uint256 MINMUM_VALUE = 100 * 10 ** 18;

    AggregatorV3Interface internal dataFeed;
    // 目标值
    uint256 constant TARGET = 1000 * 10 * 18;
    
    address public  owner;

    uint256 deploymentTimeStamp;

    uint256 lockTime;

    address erc20Addr;

    bool public  getFundSuccess = false;

    constructor(uint256 _lockTime) {
        // sepolia
        // https://docs.chain.link/data-feeds/price-feeds/addresses?page=1&testnetPage=1
        dataFeed = AggregatorV3Interface(
            0x694AA1769357215DE4FAC081bf1f309aDC325306
        );
        owner = msg.sender;
        deploymentTimeStamp = block.timestamp;
        lockTime = _lockTime;
    }

    function fund() external payable {
        require(converEthToUsd(msg.value) >= MINMUM_VALUE, "send more ETH");
        require(block.timestamp < deploymentTimeStamp + lockTime, "window is closed");
        funderToAmount[msg.sender] = msg.value;
    }

    /**
     * Returns the latest answer.
     * https://docs.chain.link/data-feeds/getting-started
     */
    function getChainlinkDataFeedLatestAnswer() public view returns (int) {
        // prettier-ignore
        (
            /* uint80 roundId */,
            int256 answer,
            /*uint256 startedAt*/,
            /*uint256 updatedAt*/,
            /*uint80 answeredInRound*/
        ) = dataFeed.latestRoundData();
        return answer;
    }

    // 将eth转换成USD
    function converEthToUsd(uint256 ethAmount) internal view   returns(uint256) {
        uint ethPrice = uint(getChainlinkDataFeedLatestAnswer());
        return ethAmount * ethPrice/(10**8);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        owner = newOwner;
    }

    function getFund() external windowClosed onlyOwner {
        require(converEthToUsd(address(this).balance) >= TARGET, "Target is not reached");
        // transfer: transfer ETH and revert if tx failed
        // payable(msg.sender).transfer(address(this).balance);
        //send: transfer ETH and return false if tx failed
        // bool success = payable(msg.sender).send(address(this).balance);
        // require(success, "tx failed");
        //call transfer ETH with data retrun value of function and bool
        bool success;
        (success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success, "transfer tx failed");
        if (success) {
            funderToAmount[msg.sender] = 0;
        }
        getFundSuccess = true;
    }

    function refund() external windowClosed {
        require(converEthToUsd(address(this).balance) < TARGET, "Target is reached");
        require(funderToAmount[msg.sender] !=0, "there is not fund for you");
        bool success;
        (success, ) = payable(msg.sender).call{value: funderToAmount[msg.sender]}("");
        require(success, "transfer tx failed");
        if (success) {
            funderToAmount[msg.sender] = 0;
        }
    }

    function setFunderToAmount(address funder, uint256 amountToUpdate) external  {
        require(msg.sender == erc20Addr, "you do not have permission to call function");
        funderToAmount[funder] = amountToUpdate;
    }

    function setErc20Addr(address _erc20Addr) public onlyOwner {
        erc20Addr = _erc20Addr;
    }

    modifier windowClosed() {
        require(block.timestamp >= deploymentTimeStamp + lockTime, "window is not closed");
        _;
    }

    modifier  onlyOwner () {
        require(owner == msg.sender, "this function can only called by owner");
        _;
    }
}