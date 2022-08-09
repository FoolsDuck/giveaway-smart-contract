// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "./ReentrancyGuard.sol";
import "./Maps.sol";
import "./Guilds.sol";

contract Giveaway is ReentrancyGuard, Maps {
    Guilds private guilds;

    struct Raffle {
        uint256 GuildId;
        uint256 TotalEntries;
        address Staker;
        IERC721 StakedCollection;
        uint256 StakedTokenId;
        address[] Participates;
        uint256 initialNumber;
    }

    mapping(uint256 => Raffle) raffle;
    mapping(uint256 => bool) raffleExists;
    address GuildsAddress = 0x476ffB49bD1Cf6B53E112F503d56aBAbc6E0823F;
    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        guilds = Guilds(GuildsAddress);
    }

    Guilds.Guild guild;

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
        raffle[_guildId].Participates;
        raffle[_guildId].initialNumber =
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.difficulty,
                        msg.sender
                    )
                )
            ) %
            _spots;
        raffleExists[_guildId] = true;
    }

    function reward(uint256 _guildId) external nonReentrant {
        Guilds.Guild memory _guild = guilds.getGuildById(_guildId);
        require(raffleExists[_guildId], "Raffle is not existed");
        countEntries(_guildId);
        require(
            raffle[_guildId].Participates.length >=
                raffle[_guildId].TotalEntries,
            "Giveaway is not finished"
        );
        uint256 winnerIndex = rand(
            _guildId,
            raffle[_guildId].Participates.length
        );
        address winner = raffle[_guildId].Participates[winnerIndex];
        raffle[_guildId].StakedCollection.transferFrom(
            address(this),
            winner,
            raffle[_guildId].StakedTokenId
        );
        delete raffle[_guildId];
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

    function countEntries(uint256 _guildId) private {
        Guilds.Guild memory _guild = guilds.getGuildById(_guildId);
        // push mods:
        for (uint256 i; i < _guild.GuildMods.length; i++) {
            if (_guild.GuildMods[i] != address(0)) {
                uint256 _entriesForAddress = guilds.balanceOf(
                    _guild.GuildMods[i],
                    _guildId
                );
                for (uint256 e; e < _entriesForAddress; e++) {
                    raffle[_guildId].Participates.push(_guild.GuildMods[i]);
                }
            }
        }

        // push members:
        for (uint256 i; i < _guild.GuildMembers.length; i++) {
            if (_guild.GuildMembers[i] != address(0)) {
                uint256 _entriesForAddress = guilds.balanceOf(
                    _guild.GuildMembers[i],
                    _guildId
                );
                for (uint256 e; e < _entriesForAddress; e++) {
                    raffle[_guildId].Participates.push(_guild.GuildMembers[i]);
                }
            }
        }
    }

    function rand(uint256 _guildId, uint256 _spots) private returns (uint256) {
        return
            uint256(
                keccak256(abi.encodePacked(raffle[_guildId].initialNumber++))
            ) % _spots;
    }
}
