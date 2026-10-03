--!strict
-- Who gets admin commands in live servers. Everyone testing in Studio, and
-- the game's owner, always do. Add your friends' UserIds here.

return {
	UserIds = {} :: { number },
	-- If the game is owned by a group: members at or above this rank are admins
	-- (255 = group owner only).
	GroupMinRank = 255,
}
