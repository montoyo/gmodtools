-- Useless playx protection, because i'm tired of noobs

montoyo = montoyo or {}
montoyo.prot = {}

function PlayXProtect(ent)
	assert(IsValid(ent), "Entity is not valid")
	assert(ent:GetClass():lower():find("playx"), "Entity is not a PlayX entity")
	
	table.insert(montoyo.prot, ent)
end

function PlayXUnprotect(ent)
	assert(IsValid(ent), "Entity is not valid")
	assert(ent:GetClass():lower():find("playx"), "Entity is not a PlayX entity")
	
	for k, v in pairs(montoyo.prot) do
		if v == ent then
			table.remove(montoyo.prot, k)
			return
		end
	end
	
	print("Entity is not protected.")
end

hook.Add("PlayXMediaOpen", "PlayXProtect", function(self)
	for k, v in pairs(montoyo.prot) do
		if v == self then
			print("Cannot open a media for this entity, since it has been protected.")
			return "no no no nigga"
		end
	end
end)
