-- ClientState: latest server snapshot + change signal shared by every controller
local State = { Data = nil, CutsceneBusy = false, Quick = false, Auto = false }
local changed = Instance.new("BindableEvent")
State.Changed = changed.Event
function State.Set(data) State.Data = data; changed:Fire(data) end
return State
