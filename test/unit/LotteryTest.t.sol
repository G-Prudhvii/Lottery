// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Lottery} from "../../src/Lottery.sol";
import {DeployLottery} from "../../script/DeployLottery.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
// import {StdCheats} from "forge-std/StdCheats.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/Mocks/VRFCoordinatorV2Mock.sol";

contract LotteryTest is Test {
    event EnteredLottery(address indexed player);

    Lottery public lottery;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployLottery deployer = new DeployLottery();

        (lottery, helperConfig) = deployer.run();

        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link
        ) = helperConfig.activeNetworkConfig();

        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testLotteryInitializesInOpenState() public view {
        assert(lottery.getLotteryState() == Lottery.LotteryState.OPEN);
    }

    function testRaffleRevertsWhenYouDontPayEnough() public {
        vm.prank(PLAYER);
        vm.expectRevert(Lottery.Lottery__NotEnoughEthSent.selector);

        lottery.enterLottery();
    }

    function testLotteryRecordsPlayerWhenTheyEnter() public {
        vm.prank(PLAYER);
        lottery.enterLottery{value: entranceFee}();
        address playerRecorded = lottery.getPlayer(0);

        assert(playerRecorded == PLAYER);
    }

    function testEmitsEventOnEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(lottery));
        emit EnteredLottery(PLAYER);
        lottery.enterLottery{value: entranceFee}();
    }

    function testCantEnterWhenLotteryIsClosed() public {
        vm.prank(PLAYER);
        lottery.enterLottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        lottery.performUpKeep("");

        vm.expectRevert(Lottery.Lottery__LotteryClosed.selector);
        vm.prank(PLAYER);
        lottery.enterLottery{value: entranceFee}();
    }

    function testCheckUpKeepReturnsFalseIfIthasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upKeepNeeded, ) = lottery.checkUpkeep("");

        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfLotteryClosed() public {
        vm.prank(PLAYER);
        lottery.enterLottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        lottery.performUpKeep("");

        (bool upKeepNeeded, ) = lottery.checkUpkeep("");
        assert(upKeepNeeded == false);
    }

    // function testFulfillREandomWordsPicksAWinnerResetsAndSendsMoney() public {
    //     vm.prank(PLAYER);
    //     lottery.enterLottery{value: entranceFee}();
    //     vm.warp(block.timestamp + interval + 1);
    //     vm.roll(block.number + 1);

    //     uint256 additionalEntrants = 5;
    //     uint256 startingIndex = 1;

    //     for (
    //         uint256 i = startingIndex;
    //         i < startingIndex + additionalEntrants;
    //         i++
    //     ) {
    //         address player = address(uint160(i));
    //         hoax(player, 1 ether);
    //         lottery.enterLottery{value: entranceFee}();
    //     }

    //     uint256 prize = entranceFee * (additionalEntrants + 1);

    //     vm.recordLogs();
    //     lottery.performUpKeep("");
    //     Vm.Log[] memory entries = vm.getRecordedLogs();
    //     bytes32 requestId = entries[0].topics[0];

    //     // console.log(requestId);

    //     uint256 previousTimeStamp = lottery.getLastTimeStamp();

    //     VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
    //         uint256(requestId),
    //         address(lottery)
    //     );

    //     // assert(uint256(lottery.getLotteryState()) == 0);
    //     // assert(lottery.getRecentWinner() != address(0));
    //     // assert(lottery.getLengthgOfPlayers() == 0);
    //     // assert(previousTimeStamp < lottery.getLastTimeStamp());
    //     // assert(
    //     //     lottery.getRecentWinner().balance ==
    //     //         STARTING_USER_BALANCE + prize - entranceFee
    //     // );
    // }
}
