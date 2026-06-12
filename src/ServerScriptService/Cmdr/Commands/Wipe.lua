return {
	Name = script.Name;
	Aliases = {"wipe"};
	Description = "Wipes a player data";
	Group = "Admin";
	Args = {
		{
			Type = "players";
			Name = "from";
			Description = "The players to wipe the data";
		},
	};
}