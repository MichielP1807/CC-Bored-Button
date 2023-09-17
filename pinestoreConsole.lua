-- PineStore Console Edition by Xella
-- Modified by Michiel

local apiPath = "https://pinestore.cc/api/"

local installDir = "installed"

if not fs.exists(installDir) then
	fs.makeDir(installDir)
end

local function getAPI(path)
	local res = http.get(apiPath .. path)
	if not res then
		online = false
		return
	end
	local data = res.readAll()
	res.close()
	return textutils.unserialiseJSON(data)
end

function postAPI(path, body)
	local res = http.post(apiPath .. path, textutils.serialiseJSON(body), { ["Content-Type"] = "application/json" })
	if not res then
		return
	end
	local data = res.readAll()
	res.close()
	return textutils.unserialiseJSON(data)
end

local installedInfo = {
	projects = {},
}
if fs.exists("installed.json") then
	local h = fs.open("installed.json", "r")
	installedInfo = textutils.unserialiseJSON(h.readAll())
	h.close()
end
local function saveInstalled()
	local encoded = textutils.serialiseJSON(installedInfo)
	local h = fs.open("installed.json", "w")
	h.write(encoded)
	h.close()
end


-- Get projects from API
local projects = getAPI("projects").projects
if not projects then
	-- Could not load projects, load from installedInfo instead
	local ps = {}
	for id, project in pairs(installedInfo.projects) do
		ps[#ps + 1] = project
	end
	projects = ps
else
	-- Add projects to installedInfo
	for i = 1, #projects do
		local project = projects[i]
		if installedInfo.projects[tostring(project.id)] then
			installedInfo.projects[tostring(project.id)].downloads = project.downloads
		end
	end
	saveInstalled()
end

-- Remove projects without install command or target file
for i = #projects, 1, -1 do
	local project = projects[i]
	if not project.install_command or not project.target_file then
		table.remove(projects, i)
	end
end


-- Sort fun projects
local funProjects = {}
for i = 1, #projects do
	local project = projects[i]
	if project.category == "fun" then
		funProjects[#funProjects + 1] = project
	end
end



local function installProject(project)
	-- redirect term to old one
	-- term.redirect(oldTerm)

	-- override fs methods
	local projectPath = installDir .. "/" .. project.id .. "/"
	fs.makeDir(projectPath)
	local oldFSOpen = fs.open
	local oldFSMakeDir = fs.makeDir
	local oldFSExists = fs.exists
	function fs.open(path, mode)
		-- print("open " .. path)
		-- sleep(0.5)
		if path:sub(1, 12) == "rom/programs" then
			return oldFSOpen(path, mode)
		end
		return oldFSOpen(projectPath .. path, mode)
	end

	function fs.makeDir(path)
		return oldFSMakeDir(projectPath .. path)
	end

	function fs.exists(path)
		if path:sub(1, 12) == "rom/programs" then
			return oldFSExists(path)
		end
		return oldFSExists(projectPath .. path)
	end

	-- actually run the install command
	local success, res = xpcall(shell.run, debug.traceback, project.install_command)

	-- return old fs methods
	fs.open = oldFSOpen
	fs.makeDir = oldFSMakeDir
	fs.exists = oldFSExists

	-- use render window again
	-- oldTerm = term.redirect(renderWindow)

	-- updateTermSize()

	if success then
		-- set project info to installed
		installedInfo.projects[tostring(project.id)] = project
		saveInstalled()
		-- postAPI("newdownload", { projectId = project.id })
	else
		error(res)
	end
end

local function startProject(project)
	-- override fs methods
	local projectPath = installDir .. "/" .. project.id .. "/"
	local oldFSOpen = fs.open
	local oldFSMakeDir = fs.makeDir
	local oldFSExists = fs.exists
	local oldFSList = fs.list
	function fs.open(path, mode)
		if path:sub(1, 12) == "rom/programs" then
			return oldFSOpen(path, mode)
		end
		return oldFSOpen(projectPath .. path, mode)
	end

	function fs.makeDir(path)
		return oldFSMakeDir(projectPath .. path)
	end

	function fs.exists(path)
		return oldFSExists(projectPath .. path)
	end

	function fs.list(path)
		return oldFSList(projectPath .. path)
	end

	-- term.redirect(oldTerm)
	local success, res = xpcall(function()
		local success = shell.run(project.target_file)

		if not success then
			sleep(1)
			term.setTextColor(colors.white)
			print("\nPress any key to continue...")
			os.pullEvent("key")
		end
	end, debug.traceback)

	-- return old fs methods
	fs.open = oldFSOpen
	fs.makeDir = oldFSMakeDir
	fs.exists = oldFSExists
	fs.list = oldFSList

	if not success then
		if res:sub(1, 10) ~= "Terminated" then
			term.setBackgroundColor(colors.black)
			term.setTextColor(colors.red)
			term.clear()
			term.setCursorPos(1, 1)
			print(res)
			term.setTextColor(colors.white)
			sleep(1)
			print("\nPress any key to continue...")
			os.pullEvent("key")
		end
	end
end

return {
	funProjects = funProjects,
	installedInfo = installedInfo,
	installProject = installProject,
	startProject = startProject
}
