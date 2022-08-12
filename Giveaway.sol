// SPDX-License-Identifier: MIT
import "./Guilds.sol";
import "./ReentrancyGuard.sol";
import "./VRFConsumerBase.sol";
import "./LinkTokenInterface.sol";
import "./IERC721.sol";

pragma solidity ^0.8.4;

contract Giveaway is ReentrancyGuard, VRFConsumerBase {
    Guilds private guilds;

    struct Raffle {
        uint256 GuildId;
        uint256 TotalEntries;
        address Staker;
        IERC721 StakedCollection;
        uint256 StakedTokenId;
    }

    mapping(uint256 => Raffle) raffle;
    mapping(uint256 => bool) raffleExists;
    address GuildsAddress = 0x9c26d327435148dE06c53A014103A7a3c82c672f;
    string private _name;
    string private _symbol;
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 private randomResult;

    constructor(string memory _name_, string memory _symbol_) 
        VRFConsumerBase(
            0xf0d54349aDdcf704F77AE15b96510dEA15cb7952,
            0x514910771AF9Ca656af840dff83E8264EcF986CA 
        )
    {
        _name = _name_;
        _symbol = _symbol_;
        guilds = Guilds(GuildsAddress); 
        keyHash = 0xAA77729D3466CA35AE8D28B3BBAC7CC36A5031EFDC430821C02BC31A238AF445;
        fee = 2 * 10 ** 18;
    }

  Guilds.Guild guild;

    function getRandomNumber() public returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHash, fee);
    }

    function fulfillRandomness(bytes32, uint256 randomness) internal override {
        randomResult = randomness;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    } 

    function stake(uint256 _tokenId, IERC721 nftCollection, uint256 _guildId, uint256 _spots) external nonReentrant {
        Guilds.Guild memory _guild = guilds.getGuildById(_guildId);
        require(!raffleExists[_guildId], "Each guild can have only one giveaway at a time");
        require(_guild.Admin == msg.sender, "Only guild master can start a giveaway");
        require(guilds.totalSupply(_guildId) >= _spots, "Not enough spots to giveaway");
        require(
            nftCollection.ownerOf(_tokenId) == msg.sender,
            "You don't own this token!"
        );

        nftCollection.transferFrom(msg.sender, address(this), _tokenId);
        raffle[_guildId].GuildId = _guildId;
        raffle[_guildId].TotalEntries = _spots;
        raffle[_guildId].Staker = msg.sender;
        raffle[_guildId].StakedCollection = nftCollection;
        raffle[_guildId].StakedTokenId = _tokenId;
        raffleExists[_guildId] = true;
    }

    function reward(uint256 _guildId) external nonReentrant {
        require(raffleExists[_guildId], "Raffle is not existed");
        address[] memory totalEntries = countEntries(_guildId);
        for (uint i; i < totalEntries.length; i++) {
            if (totalEntries[i] == address(0)) {
                revert("Giveaway is not finished");
            }
        }

        require(randomResult > 0, "No random number to give, get random number and wait for oracle to finish randomness");
        uint256 winnerIndex = (randomResult % raffle[_guildId].TotalEntries);
        address winner = totalEntries[winnerIndex];
        raffle[_guildId].StakedCollection.transferFrom(address(this), winner, raffle[_guildId].StakedTokenId);
        delete raffle[_guildId];
        raffleExists[_guildId] = false;
        randomResult = 0;
    }

    function totalEntriesOfRaffle(uint256 _guildId) public view returns(uint256) {
        return raffle[_guildId].TotalEntries;
    }

    function rewardToken(uint256 _guildId) public view returns(uint256) {
        return raffle[_guildId].StakedTokenId;
    }

    function rewardCollection(uint256 _guildId) public view returns(IERC721) {
        return raffle[_guildId].StakedCollection;
    }


    function countEntries(uint256 _guildId)
        public
        view
        returns (address[] memory)
    {
        Guilds.Guild memory _guild = guilds.getGuildById(_guildId);
        uint maxSpots = raffle[_guildId].TotalEntries;
        address[] memory participants = new address[](maxSpots);
        uint256 lastIndexFilled;

        if (_guild.GuildMembers.length > 0) {
        for (uint i; i < _guild.GuildMembers.length; i++) {
            if (_guild.GuildMembers[i] != address(0)) {
                 uint256 _entriesForAddress = guilds.balanceOf(
                    _guild.GuildMembers[i],
                    _guildId
                );
                for (uint256 x; x < _entriesForAddress; x++) {
                    uint indexToUpdate = x + lastIndexFilled;
                    if (indexToUpdate < maxSpots) {
                    participants[indexToUpdate] = _guild.GuildMembers[i];
                    }
                } 
                lastIndexFilled += _entriesForAddress;  
            }             
        }
        }

        if (_guild.GuildMods.length > 0) {
        for (uint i; i < _guild.GuildMods.length; i++) {
            if (_guild.GuildMods[i] != address(0)) {
                 uint256 _entriesForAddress = guilds.balanceOf(
                    _guild.GuildMods[i],
                    _guildId
                );
                for (uint256 x; x < _entriesForAddress; x++) {
                    uint indexToUpdate = x + lastIndexFilled;
                    if (indexToUpdate < maxSpots) {
                    participants[indexToUpdate] = _guild.GuildMods[i];
                    }
                } 
                lastIndexFilled += _entriesForAddress; 
            }    
        }
        }

        return participants;
    }


    function indexOfAddress(address[] memory arr, address searchFor)
        private
        pure
        returns (uint256)
    {
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == searchFor) {
                return i;
            }
        }
        revert("Address Not Found");
    }

}
