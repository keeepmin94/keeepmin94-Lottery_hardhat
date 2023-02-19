// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15; 

contract CommitRevealLottery {
    uint public commitCloses;
    uint public revealCloses;
    uint public constant DURATION = 4;

    uint public lotteryId;
    address[] public players;
    address public winner;
    bytes32 seed;
    mapping (address => bytes32) public commitments;
    mapping (uint256 => address) public lotteryHistory;

    constructor() {
        commitCloses = block.number + DURATION;
        revealCloses = commitCloses + DURATION;
    }

    //참여자는 외부에서 secret 값을 생성한 후 해시하여 commit 값 생성 후, 0.01 이상의 ETH와 함께 commit 값을 등록
    function enter(bytes32 commitment) public payable {
        require(msg.value >= .01 ether, "msg.value should be greater than equal to 0.01 ether");
        require(block.number < commitCloses, "commit duration is over");
        commitments[msg.sender] = commitment;
    }

    //컨트랙트에서의 commit값 생성 로직 (함수를 콜한 주소와 입력한 secret값을 해시한 값)
    function createCommitment(uint secret) public view returns (bytes32) {
        return keccak256(abi.encodePacked(msg.sender, secret));
    }

    //commit시 참여했던 자가 그 당시 사용한 secret 값 공개하며, 이를 이용해 랜덤값 생성
    function reveal(uint256 secret) public {
        require(block.number >= commitCloses, "commit duration is not clodes yet");
        require(block.number < revealCloses, "reveal duration is already closed");

        bytes32 commit = createCommitment(secret);
        require(commit == commitments[msg.sender], "commit not macthed");

        seed = keccak256(abi.encodePacked(seed, secret));
        players.push(msg.sender);
    }

    //reveal 단계에서 결정된 랜덤값인 seed를 통해 참여한 players 중 winner 선정
    // 충분한 참여기간 지난 후에 호출 가능하므로 onlyOwner일 필요 없음
    function pickWinner() public {
        require(block.number >= revealCloses, "Not yet to pick winner");
        require(winner == address(0), "winner is already set");

        winner = players[uint(seed) % players.length];

        lotteryHistory[lotteryId] = winner;
        lotteryId++;
    }

    //함수 호출자가 winner일 경우 컨트랙트에 쌓인 모든 ETH 획득
    // 다음 회차를 위해 관련 데이터들 초기화 및 commit, reveal 기간 재설정
    function withDrawPrize() public {
        require(msg.sender == winner, "You're not the winner");

        // initialize for next phase
        delete winner;
        for(uint i=0; i < players.length;i++){
            delete commitments[players[i]];
        }
        delete players;
        delete seed;

        commitCloses = block.number + DURATION;
        revealCloses = commitCloses + DURATION;

        (bool success, ) = payable(msg.sender).call{value:address(this).balance}("");
        require(success, "Failed to send Ether to winner");
    }
}