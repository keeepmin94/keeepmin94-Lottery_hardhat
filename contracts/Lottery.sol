// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15; //^0.8.15 의미: 0.8.15 <= 허용 < 0.9.0

contract Lottery {
    address public owner;
    address payable[] public players;//address payable: ETH를 수신할 수 있는 address 타입
    //나중에 winner 선정시 players 리스트 중에 선정 -> winner는 ETH를 받으므로 address payable 타입이어야함

    uint256 public lotteryId;
    mapping(uint256 => address) public lotteryHistory;

    constructor() {
        owner = msg.sender;
    }

    function getBalance() public view returns(uint256) {
        return address(this).balance;
    }

    //memory: players 값은 storage에 저장되어 있는 값이므로 이 내용을 읽어서 return하고자 할 경우엔 memory 타입이어야함
    function getPlayers() public view returns(address payable[] memory){
        return players;
    }

    //enter() 함수는 사용자로부터 ETH를 전송받을 목적의 함수이므로 payable 타입이어야함
    function enter() public payable {
        require(msg.value >= .01 ether, "msg.value should be greater than equal to 0.01 ether");
        players.push(payable(msg.sender));
    }

    function getRandomNumber() public view returns(uint256) {
        //abi.encodePacked(owner, block.timestamp): owner와 block.timestamp 각각을 bytes로 converting한 값을 concat한 값
        return uint256(keccak256((abi.encodePacked(owner, block.timestamp))));
    }
    //block.timestamp 외에 또다른 블록 상태값 이용하는 것도 가능
    function getRandomNumberV2() public view returns(uint256) {
        return uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, players)));
    }
    function getRandomNumberV3() public view returns(uint256) {
        return uint256(keccak256(abi.encodePacked(blockhash(block.number -1), block.timestamp)));
    }    
    /*
    이렇게 컨트랙트 변수 및 블록 상태값을 이용한 PRNG는 같은 트랜잭션 내에서 값이 동일함 à 블록체인은 deterministic하기 때문
    즉, 블록체인 특성상 같은 트랜잭션 내에서랜덤값이 다를 수 없음
    */    

    function pickWinner() public onlyOwner {
        uint256 index = getRandomNumber() % players.length;

        lotteryHistory[lotteryId] = players[index];
        lotteryId++;
        //다른 컨트랙트와 인터렉션하기전에 모든 상태값을 변경하는 습관 들이기(무한 call)
        //re-entrancy attack 방지(공격자 컨트랙트(EOA가 아니라 다른 컨트랙트를 일부러) 악의적 공격 방지)
        (bool success, ) = players[index].call{value: address(this).balance}(""); //우승자에게 이더 보내기(요즘 가장 많이 사용하는 방식)
        require(success, "Failed to send Ether");

        players = new address payable[](0); //다음 회차를 위해 players 초기화
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
}

// 모든 컨트랙트 소스코드 상단에 SPDX License 정보를 주석으로 추가해줘야함
// MIT License: 누구나 무상으로 소스코드 사용 가능