--!strict
-- Teams (docs/menu_systems_brief.txt D5): inside one server, not saved.
return {
	MaxMembers = 5,
	InviteSeconds = 30, -- an invite expires after this
	InviteInterval = 1.5, -- seconds between two invites from the same player (rate limit)
	NearbyStuds = 120, -- the Invite tab lists players closer than this after the friends
}
