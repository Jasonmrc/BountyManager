class 'BountyManager'

function BountyManager:__init()
	Network:Subscribe("ShowPopup", self, self.ShowPopup)
end

function BountyManager:ShowPopup(infoTable)
	if infoTable.Icon then
		Game:ShowPopup(infoTable.Text, true)
	else
		Game:ShowPopup(infoTable.Text, false)
	end
end

BountyManager = BountyManager()