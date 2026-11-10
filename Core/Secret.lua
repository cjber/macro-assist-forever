local _, ns = ...

if ns.broken then
	return
end

-- Secret values. The client can hand an addon a value it may hold but not read: another unit's name in some combat
-- and instance states. Comparing, matching or even testing such a value for truth raises an error, so each such
-- read passes through ns.Readable first. A tooltip the client marks forbidden must not be touched at all; ns.Usable
-- says whether one may be. The player's own level, class and name are never secret and are read directly.

---@generic T
---@param value T
---@return T?
function ns.Readable(value)
	if value == nil then
		return nil
	end
	if canaccessvalue and not canaccessvalue(value) then
		return nil
	end
	return value
end

---@param frame? Frame
---@return boolean
function ns.Usable(frame)
	if not frame then
		return false
	end
	return not (frame.IsForbidden and frame:IsForbidden())
end
