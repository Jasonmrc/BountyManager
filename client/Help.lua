function ModulesLoad()
    Events:Fire( "HelpAddItem",
        {
            name = "BountiesPlus",
            text =
				"Every time a bounty is set or claimed the data is stored for that player.\n"..
				"This means if you collect a lot of bounties it will be known that you are a Skilled Bounty Hunter.\n"..
				"\nKarma!\n"..
				"Karma happens when a bounty target kills the person who set their bounty. They receive the bounty instead.\n"..
				"\nBounty Commands:\n"..
				"'/bounty set <amount> <player>' Sets a bounty on the player. The amount is subtracted from your money.\n"..
				"'/bounty del <player>' Removes any bounty you had set on the player. The amount is returned to your money.\n"..
				"'/bounty stats' Shows your Bounty Stats and whether or not you have a bounty currently.\n"..
				"\n:: BountiesPlus was written by JasonMRC of Problem Solvers.\n" ..
				"\n"
        } )
end

function ModuleUnload()
    Events:Fire( "HelpRemoveItem",
        {
            name = "BountiesPlus"
        } )
end

Events:Subscribe("ModulesLoad", ModulesLoad)
Events:Subscribe("ModuleUnload", ModuleUnload)