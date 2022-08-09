// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

abstract contract Guilds {
    struct Guild {
        uint256 TokenId;
        string GuildName;
        string GuildDesc;
        address Admin;
        address[] GuildMembers;
        address[] GuildMods;
        string GuildType;
        uint256[] Appeals;
        uint256 UnlockDate;
        uint256 LockDate;
        string GuildRules;
        bool FreezeMetaData;
        address[] Kicked;
    }

    function getGuildById(uint256 _id)
        external
        view
        virtual
        returns (Guild memory guild);

    function balanceOf(address account, uint256 id)
        external
        view
        virtual
        returns (uint256);

    function totalSupply(uint256 id) public view virtual returns (uint256);
}
