// Anonymous Election Board
// By: Elijah Jasso
// Voting algorithm comes from "Anonymous voting by two-round public discussion (2008)" by F. Hao, P.Y.A. Ryan, P. Zieliski
// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

contract AnonymousElection {
    string name;
    // sets the owner of the election to the one who deploys the smart contract
    address private owner;

    string[] private candidates; // array of valid candidates
    address[] private voters; // array of addresses that can submit votes
    mapping(address => uint256) voterToIndex; // mapping of voter address to their index in voters
    mapping(address => bool) private canVote; // mapping that shows if an address can vote

    // indicates what round the election is on
    // round = 1, when all users are submitting their public keys. From contract start to once all have submitted their pk
    // round = 2, when all users are submitting their votes. From once everyone has submitted their pk to once everyone has submitted their vote
    // round = 3, for after everyone submits their votes
    uint256 private round;

    // these variables keep track of numbers of submissions
    uint256 private submittedPKs; // holds the number of voters who have submitted valid PKs
    uint256 private submittedVotes; // holds number of voters who have submitted their valid votes

    // cryptography related variables
    bytes private p; // prime
    bytes private g; // generator
    mapping(address => bytes) private voterPK; // mapping of users to their public keys, in the form of g^(x) (mod p)
    bytes[] private allPKBytes; // array of all PKs corresponding to voter index. In hex form
    mapping(address => bytes) private voterVotes; // mapping of users to their vote
    bytes[] private allVotes; // array of all votes corresponding to voter index. In hex form

    uint256 private m; // 2^m > number of candidates, used for tallying votes

    constructor(
        string[] memory _candidates,
        address[] memory _voters,
        bytes memory _p,
        bytes memory _g,
        address _owner,
        string memory _name
    ) {
        // check to ensure that this election makes sense, has >0 voters and >1 candidates
        // TODO: Using the solidity require function, ensure the candidate list and voter list are of non-zero length.
        require(
            _candidates.length > 1 && _voters.length > 0,
            "candidate list OR voter list are not of a non-zero length."
        );
        // TODO: instantiate round, owner, candidates, and voters.
        name = _name;
        round = 1;
        owner = _owner;
        candidates = _candidates;
        voters = _voters;

        p = _p; // prime
        g = _g; // generator
        m = 0; // 2^m > _voters.length

        // find m, 2^m > _voters.length
        while (2**m <= _voters.length) {
            m++;
        }

        submittedPKs = 0;
        submittedVotes = 0;
        allPKBytes = new bytes[](0);

        // set voter addresses to be allowed to vote
        for (uint256 i = 0; i < _voters.length; i++) {
            canVote[_voters[i]] = true;
            voterToIndex[_voters[i]] = i;
            allPKBytes.push(
                hex"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
            );
            allVotes.push(
                hex"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
            );
            voterVotes[
                _voters[i]
            ] = hex"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
        }
    }

    // for the Zero-Knowledge proof in submitPK
    // returns bytes2048
    function calculatePKHash(
        bytes memory _gv,
        bytes memory _pk,
        address _a
    ) public view returns (bytes memory) {
        bytes
            memory zeroes1792 = hex"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
        return
            abi.encodePacked(
                zeroes1792,
                bytes32(sha256(abi.encodePacked(g, _gv, _pk, _a)))
            );
    }

    function hasSubmittedPK(address _a) public view returns (bool) {
        bytes memory thisEmpty;
        return keccak256(abi.encodePacked(voterPK[_a])) != keccak256(thisEmpty);
    }

    // For the voter submitting their public key
    function submitPK(bytes memory _pk) public {
        // Ensure the following:
        //   the election is on round 1, which is the pk submitting round
        //   the sender is a verified voter and they are allowed to vote
        //   the voter has not already submitted a public key
        // TODO: Use the solidity require function to ensure these conditions.
        require(
            round == 1 && canVote[msg.sender] && !hasSubmittedPK(msg.sender)
        );
        // set relevant pk variables
        voterPK[msg.sender] = _pk; // map voter's address to their public key
        // allPK[voterToIndex[msg.sender]] = pk; // put voter's pk in correct index in allPK array
        allPKBytes[voterToIndex[msg.sender]] = _pk;

        // Increment submittedPKs and check if everyone has submitted their pk
        // TODO: increment submittedPKs
        submittedPKs += 1;
        // TODO: Check if everyone has submitted their pk, and set the round to 2.
        if (submittedPKs == voters.length) {
            round = 2;
        }
    }

    // check if voter has already submitted a vote
    // TODO: Write a function that checks if a voter has already submitted their vote.
    function hasSubmittedVote(address _address) public view returns (bool) {
        return !canVote[_address] && hasSubmittedPK(_address);
    }

    // for recording voter's vote
    // TODO: write a function "vote", that records a voter's vote.  Make sure to
    function vote(bytes memory _votersVote) public {
        // use require to ensure you are in the right round and the voter can vote.
        require(round == 2 && canVote[msg.sender]);
        canVote[msg.sender] = false;
        voterVotes[msg.sender] = _votersVote;
        allVotes[voterToIndex[msg.sender]] = _votersVote;

        // TODO: increase submittedVotes,
        submittedVotes += 1;
        // check if everyone has submitted their vote and set the round to round 3.
        if (submittedVotes == voters.length) {
            round = 3;
        }
    }

    // TODO: Develop the following getter functions.
    // return prime p
    function getPrimeP() public view returns (bytes memory) {
        return p;
    }

    // return generator g
    function getG() public view returns (bytes memory) {
        return g;
    }

    // return m
    function getM() public view returns (uint256) {
        return m;
    }

    // returns the array of potential candidates
    function getPotentialCandidates() public view returns (string[] memory) {
        return candidates;
    }

    // returns the array of voters
    function getVoters() public view returns (address[] memory) {
        return voters;
    }

    // returns the array of all public keys
    function getAllPublicKeys() public view returns (bytes[] memory) {
        // Use the require function to make sure you are in a round >= 2
        require(round >= 2, "The round is < 2");
        return allPKBytes;
    }

    // returns array of all votes
    function getAllVotes() public view returns (bytes[] memory) {
        // Use the require function to make sure you are in a round >= 3
        require(round >= 3, "The round is < 3");
        return allVotes;
    }

    // return the integer value of what round the election is on
    function getCurrentRound() public view returns (uint256) {
        return round;
    }

    // checks if address can vote
    function canAddressVote(address _address) public view returns (bool) {
        return canVote[_address];
    }
}
