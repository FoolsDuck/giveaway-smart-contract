// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "./ReentrancyGuard.sol";
import "./Maps.sol";
import "./Guilds.sol";

contract Giveaway is ReentrancyGuard, Maps {
    Guilds private guilds;

    struct Contest {
        uint256 GuildId;
        uint256 TotalEntries;
        address Staker;
        IERC721 StakedCollection;
        uint256 StakedTokenId;
        address[] Participates;
        uint256 initialNumber;
    }

    mapping(uint256 => Contest) contest;
    mapping(uint256 => bool) contestExists;
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
            !contestExists[_guildId],
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

        contest[_guildId].GuildId = _guildId;
        contest[_guildId].TotalEntries = _spots;
        contest[_guildId].Staker = msg.sender;
        contest[_guildId].StakedCollection = nftCollection;
        contest[_guildId].StakedTokenId = _tokenId;
        contest[_guildId].Participates;
        contest[_guildId].initialNumber =
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
        contestExists[_guildId] = true;
    }

    function claimReward(uint256 _guildId) external nonReentrant {
        Guilds.Guild memory _guild = guilds.getGuildById(_guildId);
        require(contestExists[_guildId], "Contest is not existed");
        require(msg.sender == _guild.Admin, "Only guild master can raffle");
        countEntries(_guildId);
        require(
            contest[_guildId].Participates.length >=
                contest[_guildId].TotalEntries,
            "Giveaway is not finished"
        );
        uint256 winnerIndex = rand(
            _guildId,
            contest[_guildId].Participates.length
        );
        address winner = contest[_guildId].Participates[winnerIndex];
        contest[_guildId].StakedCollection.transferFrom(
            address(this),
            winner,
            contest[_guildId].StakedTokenId
        );
        delete contest[_guildId];
    }

    function totalEntriesOfContest(uint256 _guildId)
        public
        view
        returns (uint256)
    {
        return contest[_guildId].TotalEntries;
    }

    function rewardToken(uint256 _guildId) public view returns (uint256) {
        return contest[_guildId].StakedTokenId;
    }

    function rewardCollection(uint256 _guildId) public view returns (IERC721) {
        return contest[_guildId].StakedCollection;
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
                    contest[_guildId].Participates.push(_guild.GuildMods[i]);
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
                    contest[_guildId].Participates.push(_guild.GuildMembers[i]);
                }
            }
        }
    }

    function rand(uint256 _guildId, uint256 _spots) private returns (uint256) {
        return
            uint256(
                keccak256(abi.encodePacked(contest[_guildId].initialNumber++))
            ) % _spots;
    }
}
