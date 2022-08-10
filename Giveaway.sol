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
    address GuildsAddress = 0x476ffB49bD1Cf6B53E112F503d56aBAbc6E0823F;
    string private _name;
    string private _symbol;
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 private randomResult;

    constructor(string memory name_, string memory symbol_)
        VRFConsumerBase(
            0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B, // VRF Coordinator
            0x01BE23585060835E02B77ef475b0Cc51aA1e0709 // LINK Token
        )
    {
        _name = name_;
        _symbol = symbol_;
        guilds = Guilds(GuildsAddress);
        keyHash = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
        fee = 0.1 * 10**18; // 0.1 LINK (Varies by network)
    }

    Guilds.Guild guild;

    function getRandomNumber() public returns (bytes32 requestId) {
        require(
            LINK.balanceOf(address(this)) >= fee,
            "Not enough LINK - fill contract with faucet"
        );
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

    function stake(
        uint256 _tokenId,
        IERC721 nftCollection,
        uint256 _guildId,
        uint256 _spots
    ) external nonReentrant {
        Guilds.Guild memory _guild = guilds.getGuildById(_guildId);
        require(
            !raffleExists[_guildId],
            "Each guild can have only one giveaway at a time"
        );
        require(
            _guild.Admin == msg.sender,
            "Only guild master can start a giveaway"
        );
        require(
            guilds.totalSupply(_guildId) >= _spots,
            "Not enough spots to giveaway"
        );
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
        Guilds.Guild memory _guild = guilds.getGuildById(_guildId);
        require(raffleExists[_guildId], "Raffle is not existed");
        address[] memory totalEntries = countEntries(_guildId);
        require(
            totalEntries.length >= raffle[_guildId].TotalEntries,
            "Giveaway is not finished"
        );
        require(
            randomResult > 0,
            "No random number to give, get random number and wait for oracle to finish randomness"
        );
        uint256 winnerIndex = randomResult % raffle[_guildId].TotalEntries;
        address winner = totalEntries[winnerIndex];
        raffle[_guildId].StakedCollection.transferFrom(
            address(this),
            winner,
            raffle[_guildId].StakedTokenId
        );
        delete raffle[_guildId];
        randomResult = 0;
    }

    function totalEntriesOfRaffle(uint256 _guildId)
        public
        view
        returns (uint256)
    {
        return raffle[_guildId].TotalEntries;
    }

    function rewardToken(uint256 _guildId) public view returns (uint256) {
        return raffle[_guildId].StakedTokenId;
    }

    function rewardCollection(uint256 _guildId) public view returns (IERC721) {
        return raffle[_guildId].StakedCollection;
    }

    function countEntries(uint256 _guildId)
        private
        view
        returns (address[] memory)
    {
        Guilds.Guild memory _guild = guilds.getGuildById(_guildId);
        address[] memory participants = new address[](raffle[_guildId].TotalEntries);
        // push mods:
        for (uint256 i; i < _guild.GuildMods.length; i++) {
            if (_guild.GuildMods[i] != address(0)) {
                uint256 _entriesForAddress = guilds.balanceOf(
                    _guild.GuildMods[i],
                    _guildId
                );
                for (uint256 e; e < _entriesForAddress; e++) {
                    participants[participants.length] = _guild.GuildMods[i];
                }
            }
        }

        // push members:
        for (uint256 i = 0; i < _guild.GuildMembers.length; i++) {
            if (_guild.GuildMembers[i] != address(0)) {
                uint256 _entriesForAddress = guilds.balanceOf(
                    _guild.GuildMembers[i],
                    _guildId
                );
                for (uint256 e; e < _entriesForAddress; e++) {
                    participants[participants.length] = _guild.GuildMembers[i];
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
