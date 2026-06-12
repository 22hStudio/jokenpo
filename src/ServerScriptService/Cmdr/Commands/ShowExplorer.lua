return {
    Name = "showExplorer";
    Aliases = {};
    Description = "Gives a player an explorer instance, similar to Roblox Studio's explorer.";
    Group = script.Parent.Name;
    Args = {
        {
            Type = "players";
            Name = "player";
            Description = "Players to give the explorer.";
        },
    };
}